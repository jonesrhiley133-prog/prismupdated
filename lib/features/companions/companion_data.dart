import 'dart:math' as math;

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/features/companions/companion_art.dart';
import 'package:prism_plurality/features/companions/companion_species.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Virtual Companions data. Everything is a synced tracker record with a
/// schema version in `fields.v`, so it is backed up, exported, synced and
/// resettable like the rest of Prism.
///
/// Design rule: companions have no needs. Nothing here decays, expires or
/// counts days. Leave for months and they're exactly as you left them.
const companionSchemaVersion = 1;

List<String> _strs(Object? v) => [
  for (final x in (v as List?) ?? const []) '$x',
];

enum OwnerType {
  member('One headmate'),
  members('Several headmates'),
  subsystem('Subsystem'),
  system('Whole system'),
  none('Unassigned');

  const OwnerType(this.label);
  final String label;
}

class Companion {
  Companion(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.isEmpty ? 'Companion' : r.title;
  String get nickname => '${r.fields['nickname'] ?? ''}';
  String get speciesId => '${r.fields['species'] ?? 'cat'}';
  String? get customSpeciesId => r.fields['customSpecies'] as String?;
  Species get species => speciesById(speciesId);
  List<String> get traits => _strs(r.fields['traits']);
  String get customPersonality => '${r.fields['customPersonality'] ?? ''}';
  String get pronouns => '${r.fields['pronouns'] ?? ''}';
  DateTime get adoptedAt =>
      DateTime.tryParse('${r.fields['adoptedAt'] ?? ''}') ?? r.createdAt;

  /// "MM-DD" (or a full date) — optional.
  String? get birthday =>
      (r.fields['birthday'] as String?)?.trim().isEmpty ?? true
      ? null
      : r.fields['birthday'] as String;
  OwnerType get ownerType =>
      OwnerType.values
          .where((o) => o.name == r.fields['ownerType'])
          .firstOrNull ??
      OwnerType.none;
  List<String> get owners => _strs(r.fields['owners']);
  List<String> get favActivities => _strs(r.fields['favActivities']);
  List<String> get favFoods => _strs(r.fields['favFoods']);
  List<String> get favAccessories => _strs(r.fields['favAccessories']);
  String get bio => r.body ?? '';
  String get status => '${r.fields['status'] ?? ''}';
  String? get avatarMedia => r.fields['avatar'] as String?;
  String? get bannerMedia => r.fields['banner'] as String?;
  CompanionLook get look => CompanionLook.fromJson(r.fields['look']);
  String? get outfitId => r.fields['outfit'] as String?;
  String? get habitatId => r.fields['habitat'] as String?;
  List<String> get tags => _strs(r.fields['tags']);
  String get notes => '${r.fields['notes'] ?? ''}';
  String get eggStyle => '${r.fields['egg'] ?? 'classic'}';
  DateTime? get hatchAt => DateTime.tryParse('${r.fields['hatchAt'] ?? ''}');

  /// Still an egg (a scheduled hatch that hasn't come yet).
  bool get isEgg => hatchAt != null && hatchAt!.isAfter(DateTime.now());
  bool get favorite => r.flag('favorite');
  String get displayName => nickname.isEmpty ? name : '$name "$nickname"';

  /// Whether [memberId] is one of this companion's owners (system and
  /// unassigned companions belong to everyone).
  bool ownedBy(String memberId, {List<String> subsystemMembers = const []}) =>
      switch (ownerType) {
        OwnerType.member || OwnerType.members => owners.contains(memberId),
        OwnerType.subsystem => subsystemMembers.contains(memberId),
        OwnerType.system || OwnerType.none => true,
      };
}

class CompanionOutfit {
  CompanionOutfit(this.r);
  final TrackerRecord r;
  String get name => r.title.isEmpty ? 'Outfit' : r.title;
  CompanionLook get look => CompanionLook.fromJson(r.fields['look']);
}

class CustomSpecies {
  CustomSpecies(this.r);
  final TrackerRecord r;
  String get name => r.title.isEmpty ? 'Custom creature' : r.title;
  String? get media => r.fields['image'] as String?;

  /// Built from a base species, with optional uploaded artwork.
  String get baseId => '${r.fields['base'] ?? 'slime'}';
  Species get base => speciesById(baseId);
}

/// Habitat environments, drawn as layered gradients and shapes.
class HabitatEnv {
  const HabitatEnv(
    this.id,
    this.name,
    this.emoji,
    this.sky,
    this.ground, {
    this.indoor = false,
    this.water = false,
  });
  final String id;
  final String name;
  final String emoji;
  final List<Color> sky;
  final Color ground;
  final bool indoor;
  final bool water;
}

const habitatEnvs = <HabitatEnv>[
  HabitatEnv(
    'bedroom',
    'Cozy bedroom',
    '🛏️',
    [Color(0xFFF7E3D3), Color(0xFFF2D1BE)],
    Color(0xFFC79C7E),
    indoor: true,
  ),
  HabitatEnv('clearing', 'Woodland clearing', '🌳', [
    Color(0xFFBFE3F2),
    Color(0xFFE4F3E0),
  ], Color(0xFF8CC17A)),
  HabitatEnv('celestial', 'Celestial garden', '🌌', [
    Color(0xFF1E2350),
    Color(0xFF4A3F86),
  ], Color(0xFF3B6A62)),
  HabitatEnv(
    'aquarium',
    'Aquarium',
    '🐠',
    [Color(0xFF7FD0F0), Color(0xFF2E86C1)],
    Color(0xFFE8D8A8),
    water: true,
  ),
  HabitatEnv('mushroom', 'Mushroom forest', '🍄', [
    Color(0xFF3C2E5A),
    Color(0xFF6B4E7A),
  ], Color(0xFF4F6B3A)),
  HabitatEnv('cloud', 'Cloud island', '☁️', [
    Color(0xFFB9DDFF),
    Color(0xFFFFE6F2),
  ], Color(0xFFFFFFFF)),
  HabitatEnv('crystal', 'Crystal cave', '💎', [
    Color(0xFF2A2140),
    Color(0xFF4D3B70),
  ], Color(0xFF6A5A8E)),
  HabitatEnv('beach', 'Beach', '🏖️', [
    Color(0xFF8ED6FF),
    Color(0xFFFFE9C2),
  ], Color(0xFFF2D49B)),
  HabitatEnv('cabin', 'Snowy cabin', '🏔️', [
    Color(0xFFCAD8EA),
    Color(0xFFEFF3F8),
  ], Color(0xFFFFFFFF)),
  HabitatEnv('flowers', 'Flower garden', '🌷', [
    Color(0xFFCFEAFF),
    Color(0xFFFFF0F5),
  ], Color(0xFF9ED38A)),
  HabitatEnv(
    'library',
    'Library',
    '📚',
    [Color(0xFF6E4A35), Color(0xFF8C5E43)],
    Color(0xFF5A3A2A),
    indoor: true,
  ),
  HabitatEnv(
    'cottage',
    'Magical cottage',
    '🏡',
    [Color(0xFFE9D7F2), Color(0xFFF9EBD8)],
    Color(0xFF9F7E62),
    indoor: true,
  ),
  HabitatEnv(
    'space',
    'Space station',
    '🚀',
    [Color(0xFF0B1026), Color(0xFF1F2B57)],
    Color(0xFF8A93A8),
    indoor: true,
  ),
  HabitatEnv('zen', 'Japanese-inspired garden', '⛩️', [
    Color(0xFFFFE5DC),
    Color(0xFFF7F0E1),
  ], Color(0xFFCFC3A6)),
];

HabitatEnv habitatEnvById(String? id) =>
    habitatEnvs.where((e) => e.id == id).firstOrNull ?? habitatEnvs.first;

/// Decorations that can be placed in a habitat.
const habitatDecor = <String, String>{
  'plant': '🪴',
  'lamp': '🛋️',
  'bed': '🛏️',
  'books': '📚',
  'flowers': '💐',
  'tree': '🌳',
  'pine': '🌲',
  'mushroom': '🍄',
  'rock': '🪨',
  'shell': '🐚',
  'star': '⭐',
  'moon': '🌙',
  'lantern': '🏮',
  'candle': '🕯️',
  'gift': '🎁',
  'ball': '⚽',
  'yarn': '🧶',
  'teddy': '🧸',
  'cushion': '🟣',
  'rug': '🟫',
  'crystal': '💎',
  'bonsai': '🎍',
  'fish': '🐟',
  'coral': '🪸',
  'snowman': '⛄',
  'fire': '🔥',
  'tea': '🍵',
  'cake': '🍰',
  'frame': '🖼️',
  'clock': '🕰️',
  'telescope': '🔭',
  'planet': '🪐',
  'rocket': '🚀',
  'cherry': '🌸',
  'bamboo': '🎋',
  'torii': '⛩️',
  'sunflower': '🌻',
  'tulip': '🌷',
  'cactus': '🌵',
  'music': '🎵',
};

class HabitatItem {
  const HabitatItem(this.id, this.type, this.x, this.y, {this.scale = 1});
  final String id;
  final String type;

  /// 0–1 positions inside the scene.
  final double x, y;
  final double scale;
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'scale': scale,
  };
  static HabitatItem fromJson(Map j) => HabitatItem(
    '${j['id']}',
    '${j['type']}',
    ((j['x'] as num?) ?? 0.5).toDouble().clamp(0, 1),
    ((j['y'] as num?) ?? 0.7).toDouble().clamp(0, 1),
    scale: ((j['scale'] as num?) ?? 1).toDouble().clamp(0.4, 2.5),
  );
  HabitatItem copyWith({double? x, double? y, double? scale}) => HabitatItem(
    id,
    type,
    x ?? this.x,
    y ?? this.y,
    scale: scale ?? this.scale,
  );
}

class Habitat {
  Habitat(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.isEmpty ? habitatEnvById(env).name : r.title;
  String get env => '${r.fields['env'] ?? 'bedroom'}';
  String get timeOfDay => '${r.fields['time'] ?? 'auto'}';
  String get weather => '${r.fields['weather'] ?? 'clear'}';
  String get lighting => '${r.fields['lighting'] ?? 'soft'}';
  List<HabitatItem> get items => [
    for (final i in (r.fields['items'] as List? ?? const []))
      if (i is Map) HabitatItem.fromJson(i),
  ];
}

class CompanionInteraction {
  CompanionInteraction(this.r);
  final TrackerRecord r;
  String get kind => '${r.fields['kind'] ?? 'pet'}';
  String get companionId => r.parentId ?? '';
  String? get by => r.memberId;
  String get flavor => r.body ?? '';
  DateTime get at => r.occurredAt ?? r.createdAt;
}

/// A saved moment: a photo (stored as a re-drawable scene), a note, or a
/// milestone like adoption.
class CompanionMemory {
  CompanionMemory(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get kind => '${r.fields['kind'] ?? 'note'}';
  List<String> get companionIds =>
      _strs(r.fields['companions']).isEmpty && r.parentId != null
      ? [r.parentId!]
      : _strs(r.fields['companions']);
  String get title => r.title;
  String get caption => r.body ?? '';
  DateTime get at => r.occurredAt ?? r.createdAt;
  PhotoScene? get scene => r.fields['scene'] is Map
      ? PhotoScene.fromJson(r.fields['scene']! as Map)
      : null;
  String? get media => r.fields['media'] as String?;
}

/// A companion photo, kept as a scene so it can be redrawn at any size.
class PhotoScene {
  const PhotoScene({
    this.background = 'clearing',
    this.subjects = const [],
    this.stickers = const [],
    this.text = '',
    this.textColor = 0xFFFFFFFF,
    this.frame = 'none',
    this.time = 'auto',
  });
  final String background;
  final List<PhotoSubject> subjects;
  final List<PhotoSticker> stickers;
  final String text;
  final int textColor;
  final String frame;
  final String time;

  Map<String, Object?> toJson() => {
    'background': background,
    'subjects': [for (final s in subjects) s.toJson()],
    'stickers': [for (final s in stickers) s.toJson()],
    'text': text,
    'textColor': textColor,
    'frame': frame,
    'time': time,
  };
  static PhotoScene fromJson(Map j) => PhotoScene(
    background: '${j['background'] ?? 'clearing'}',
    subjects: [
      for (final s in (j['subjects'] as List? ?? const []))
        if (s is Map) PhotoSubject.fromJson(s),
    ],
    stickers: [
      for (final s in (j['stickers'] as List? ?? const []))
        if (s is Map) PhotoSticker.fromJson(s),
    ],
    text: '${j['text'] ?? ''}',
    textColor: (j['textColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
    frame: '${j['frame'] ?? 'none'}',
    time: '${j['time'] ?? 'auto'}',
  );
  PhotoScene copyWith({
    String? background,
    List<PhotoSubject>? subjects,
    List<PhotoSticker>? stickers,
    String? text,
    int? textColor,
    String? frame,
    String? time,
  }) => PhotoScene(
    background: background ?? this.background,
    subjects: subjects ?? this.subjects,
    stickers: stickers ?? this.stickers,
    text: text ?? this.text,
    textColor: textColor ?? this.textColor,
    frame: frame ?? this.frame,
    time: time ?? this.time,
  );
}

class PhotoSubject {
  const PhotoSubject(
    this.companionId, {
    this.pose = 'sit',
    this.expression = 'happy',
    this.x = 0.5,
    this.y = 0.62,
    this.scale = 1,
    this.look,
  });
  final String companionId;
  final String pose, expression;
  final double x, y, scale;

  /// The companion's look when the photo was taken (photos don't change
  /// when outfits do).
  final Map<String, Object?>? look;
  Map<String, Object?> toJson() => {
    'id': companionId,
    'pose': pose,
    'expression': expression,
    'x': x,
    'y': y,
    'scale': scale,
    'look': look,
  };
  static PhotoSubject fromJson(Map j) => PhotoSubject(
    '${j['id']}',
    pose: '${j['pose'] ?? 'sit'}',
    expression: '${j['expression'] ?? 'happy'}',
    x: ((j['x'] as num?) ?? 0.5).toDouble(),
    y: ((j['y'] as num?) ?? 0.62).toDouble(),
    scale: ((j['scale'] as num?) ?? 1).toDouble(),
    look: (j['look'] as Map?)?.cast<String, Object?>(),
  );
  PhotoSubject copyWith({
    String? pose,
    String? expression,
    double? x,
    double? y,
    double? scale,
  }) => PhotoSubject(
    companionId,
    pose: pose ?? this.pose,
    expression: expression ?? this.expression,
    x: x ?? this.x,
    y: y ?? this.y,
    scale: scale ?? this.scale,
    look: look,
  );
}

class PhotoSticker {
  const PhotoSticker(this.emoji, {this.x = 0.2, this.y = 0.2, this.scale = 1});
  final String emoji;
  final double x, y, scale;
  Map<String, Object?> toJson() => {'e': emoji, 'x': x, 'y': y, 'scale': scale};
  static PhotoSticker fromJson(Map j) => PhotoSticker(
    '${j['e'] ?? '⭐'}',
    x: ((j['x'] as num?) ?? 0.2).toDouble(),
    y: ((j['y'] as num?) ?? 0.2).toDouble(),
    scale: ((j['scale'] as num?) ?? 1).toDouble(),
  );
  PhotoSticker copyWith({double? x, double? y, double? scale}) => PhotoSticker(
    emoji,
    x: x ?? this.x,
    y: y ?? this.y,
    scale: scale ?? this.scale,
  );
}

/// Where companions appear and which notifications are on. Everything off
/// by default except the Home card once a companion exists.
class CompanionSettings {
  const CompanionSettings({
    this.record,
    this.placements = const {
      'dashboard': true,
      'profile': true,
      'emptyStates': true,
    },
    this.choice = 'featured',
    this.featuredId,
    this.notify = const {},
    this.passportSuggestions = true,
  });
  final TrackerRecord? record;
  final Map<String, bool> placements;

  /// featured | rotate | profile (the one owned by whoever is fronting).
  final String choice;
  final String? featuredId;
  final Map<String, bool> notify;
  final bool passportSuggestions;

  static const placementLabels = {
    'habitatPreview': 'Habitat preview on Home',
    'besideFronter': 'Beside the current fronter',
    'profile': 'On headmate profiles',
    'launch': 'On the opening screen',
    'emptyStates': 'Beside empty-page messages',
    'floating': 'Peeking in at the top of Home',
  };
  static const notifyLabels = {
    'anniversary': 'Adoption anniversaries',
    'birthday': 'Companion birthdays',
    'seasonal': 'New seasonal looks',
    'memories': 'Memories from this day',
  };

  bool shows(String placement) => placements[placement] ?? false;

  Map<String, Object?> toFields() => {
    'v': companionSchemaVersion,
    'placements': placements,
    'choice': choice,
    'featured': featuredId,
    'notify': notify,
    'passport': passportSuggestions,
  };

  static CompanionSettings of(TrackerRecord? r) {
    if (r == null) return const CompanionSettings();
    final f = r.fields;
    Map<String, bool> bools(Object? v, Map<String, bool> d) =>
        v is Map ? {for (final e in v.entries) '${e.key}': e.value == true} : d;
    return CompanionSettings(
      record: r,
      placements: bools(f['placements'], const {
        'dashboard': true,
        'profile': true,
        'emptyStates': true,
      }),
      choice: '${f['choice'] ?? 'featured'}',
      featuredId: f['featured'] as String?,
      notify: bools(f['notify'], const {}),
      passportSuggestions: f['passport'] != false,
    );
  }

  CompanionSettings copyWith({
    Map<String, bool>? placements,
    String? choice,
    String? featuredId,
    Map<String, bool>? notify,
    bool? passportSuggestions,
  }) => CompanionSettings(
    record: record,
    placements: placements ?? this.placements,
    choice: choice ?? this.choice,
    featuredId: featuredId ?? this.featuredId,
    notify: notify ?? this.notify,
    passportSuggestions: passportSuggestions ?? this.passportSuggestions,
  );
}

// ── Providers ────────────────────────────────────────────────────────────

List<TrackerRecord> _kind(Ref ref, String kind) =>
    ref.watch(trackerKindProvider(kind)).value ?? const <TrackerRecord>[];

final companionsProvider = Provider<List<Companion>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.companion)) Companion(r)]
        ..sort((a, b) => a.adoptedAt.compareTo(b.adoptedAt)),
);

final companionByIdProvider = Provider.family<Companion?, String>(
  (ref, id) =>
      ref.watch(companionsProvider).where((c) => c.id == id).firstOrNull,
);

final companionOutfitsProvider = Provider.family<List<CompanionOutfit>, String>(
  (ref, id) => [
    for (final r in _kind(ref, TrackerKind.companionOutfit))
      if (r.parentId == id) CompanionOutfit(r),
  ],
);

final customSpeciesProvider = Provider<List<CustomSpecies>>(
  (ref) => [
    for (final r in _kind(ref, TrackerKind.companionSpecies)) CustomSpecies(r),
  ],
);

final habitatsProvider = Provider<List<Habitat>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.companionHabitat)) Habitat(r)]
        ..sort((a, b) => a.r.createdAt.compareTo(b.r.createdAt)),
);

final companionInteractionsProvider = Provider<List<CompanionInteraction>>(
  (ref) => [
    for (final r in _kind(ref, TrackerKind.companionInteraction))
      CompanionInteraction(r),
  ]..sort((a, b) => b.at.compareTo(a.at)),
);

final companionMemoriesProvider = Provider<List<CompanionMemory>>(
  (ref) => [
    for (final r in _kind(ref, TrackerKind.companionMemory)) CompanionMemory(r),
  ]..sort((a, b) => b.at.compareTo(a.at)),
);

final companionSettingsProvider = Provider<CompanionSettings>((ref) {
  final rows = _kind(ref, TrackerKind.companionSettings);
  return CompanionSettings.of(
    rows.isEmpty
        ? null
        : (rows.toList()..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt)))
              .first,
  );
});

/// The companion to show around the app, following the user's choice.
/// [forMember] picks one that member owns when the choice is "profile".
final shownCompanionProvider = Provider.family<Companion?, String?>((
  ref,
  forMember,
) {
  final all = [
    for (final c in ref.watch(companionsProvider))
      if (!c.isEgg) c,
  ];
  if (all.isEmpty) return null;
  final s = ref.watch(companionSettingsProvider);
  if (s.choice == 'profile' && forMember != null) {
    final memberships = ref.watch(subMembershipsProvider);
    final mine = all.where((c) {
      final subMembers = c.ownerType == OwnerType.subsystem
          ? [
              for (final m in memberships)
                if (c.owners.contains(m.subsystemId)) m.memberId,
            ]
          : const <String>[];
      return c.ownedBy(forMember, subsystemMembers: subMembers) &&
          c.ownerType != OwnerType.none &&
          c.ownerType != OwnerType.system;
    }).toList();
    if (mine.isNotEmpty) return mine.first;
  }
  if (s.choice == 'rotate') {
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    return all[day % all.length];
  }
  return all.where((c) => c.id == s.featuredId).firstOrNull ??
      all.where((c) => c.favorite).firstOrNull ??
      all.first;
});

// ── Flavour text ─────────────────────────────────────────────────────────

/// Interactions. All optional; none of them is ever required.
const companionInteractions = <String, (String, String)>{
  'pet': ('Pet', '🤚'),
  'play': ('Play', '🎾'),
  'treat': ('Offer a treat', '🍪'),
  'wave': ('Wave', '👋'),
  'toy': ('Toy', '🧸'),
  'music': ('Listen to music', '🎵'),
  'read': ('Read together', '📖'),
  'sit': ('Sit together', '🪑'),
  'sleep': ('Watch them nap', '💤'),
  'explore': ('Send exploring', '🧭'),
};

CompanionPose poseFor(String interaction) => switch (interaction) {
  'wave' => CompanionPose.wave,
  'play' || 'toy' => CompanionPose.play,
  'treat' => CompanionPose.eat,
  'music' => CompanionPose.music,
  'read' => CompanionPose.read,
  'sleep' => CompanionPose.sleep,
  'pet' || 'sit' => CompanionPose.cuddle,
  'explore' => CompanionPose.hop,
  _ => CompanionPose.sit,
};

const _lines = <String, List<String>>{
  'pet': [
    '{n} leans into your hand.',
    '{n} does a happy little wiggle.',
    '{n} closes their eyes, content.',
  ],
  'play': [
    '{n} pounces and misses on purpose.',
    '{n} zooms in a happy circle.',
    '{n} brings the game right back to you.',
  ],
  'treat': [
    '{n} nibbles the treat very politely.',
    '{n} saves half for later.',
    '{n} declares it the best treat ever.',
  ],
  'wave': [
    '{n} waves back with their whole body.',
    '{n} gives a tiny wave.',
    '{n} looks delighted to see you.',
  ],
  'toy': [
    '{n} bats the toy across the room.',
    '{n} carries the toy around proudly.',
    '{n} tucks the toy somewhere safe.',
  ],
  'music': [
    '{n} sways along to the music.',
    '{n} hums a few notes off-key.',
    '{n} taps along, almost on beat.',
  ],
  'read': [
    '{n} turns a page with great care.',
    '{n} listens to every word.',
    '{n} pretends to read upside down.',
  ],
  'sit': [
    '{n} settles in beside you.',
    'You and {n} share a quiet moment.',
    '{n} rests their head against you.',
  ],
  'sleep': [
    '{n} dreams of something nice.',
    '{n} snores, very softly.',
    '{n} curls up and twitches a paw.',
  ],
};

const _traitTails = <String, List<String>>{
  'sleepy': ['Then yawns enormously.', 'Eyes getting heavier…'],
  'energetic': ['And immediately wants to go again!', 'Bouncing with energy.'],
  'curious': ['Then investigates something new.', 'Sniffing around for clues.'],
  'shy': ['Then peeks out with a small smile.', 'Quietly pleased.'],
  'playful': ['Ready for round two!', 'Clearly having fun.'],
  'affectionate': [
    'Sends a big heart your way. 💕',
    'Snuggles a little closer.',
  ],
  'mischievous': ['Plotting something harmless…', 'With a suspicious grin.'],
  'adventurous': [
    'Already dreaming of the next trip.',
    'Ears up, ready to explore.',
  ],
  'calm': ['Everything feels peaceful.', 'Breathing slow and easy.'],
  'clumsy': [
    'Then trips over nothing. Still fine!',
    'Bumps gently into a cushion.',
  ],
  'independent': ['Then wanders off to think.', 'Pleased, in their own way.'],
  'friendly': ['Says hi to everyone nearby.', 'Tail going a mile a minute.'],
  'dramatic': [
    'Strikes a pose. Applause, please.',
    'A truly theatrical moment.',
  ],
  'elegant': ['With perfect poise.', 'Every movement graceful.'],
  'silly': ['Makes a goofy face.', 'Does a little dance about it.'],
  'mysterious': ['Knows something you don\'t. ✨', 'Their eyes twinkle.'],
};

const _places = [
  'a sunny meadow',
  'a whispering library',
  'a cloud above the city',
  'a moonlit lake',
  'a crystal cave',
  'a bakery that smells amazing',
  'a tiny island',
  'a garden full of fireflies',
  'the top of a very tall tree',
  'a quiet beach at dawn',
];
const _finds = [
  'a shiny pebble',
  'a smooth seashell',
  'a four-leaf clover',
  'a tiny pinecone',
  'a feather',
  'a star-shaped leaf',
  'a lost button',
  'a drawing of you',
  'a pretty flower',
  'a nice story to tell',
];

String companionFlavor(Companion c, String interaction, {math.Random? rnd}) {
  final r = rnd ?? math.Random();
  final name = c.name;
  if (interaction == 'explore') {
    return '$name went to ${_places[r.nextInt(_places.length)]} and came back with ${_finds[r.nextInt(_finds.length)]}.';
  }
  final base = (_lines[interaction] ?? _lines['pet']!)[r.nextInt(3)].replaceAll(
    '{n}',
    name,
  );
  final traits = c.traits.where(_traitTails.containsKey).toList();
  if (traits.isEmpty || r.nextBool()) return base;
  final tail = _traitTails[traits[r.nextInt(traits.length)]]!;
  return '$base ${tail[r.nextInt(tail.length)]}';
}

// ── Actions ──────────────────────────────────────────────────────────────

class CompanionActions {
  CompanionActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord> adopt({
    required String name,
    String nickname = '',
    required String speciesId,
    String? customSpeciesId,
    required List<String> traits,
    String customPersonality = '',
    String pronouns = '',
    required OwnerType ownerType,
    required List<String> owners,
    required CompanionLook look,
    String egg = 'none',
    DateTime? hatchAt,
    String? birthday,
  }) async {
    final now = DateTime.now();
    final rec = await _t.create(
      kind: TrackerKind.companion,
      title: name.trim(),
      fields: {
        'v': companionSchemaVersion,
        'nickname': nickname.trim(),
        'species': speciesId,
        'customSpecies': customSpeciesId,
        'traits': traits,
        'customPersonality': customPersonality.trim(),
        'pronouns': pronouns.trim(),
        'adoptedAt': (hatchAt ?? now).toIso8601String(),
        'ownerType': ownerType.name,
        'owners': owners,
        'look': look.toJson(),
        'egg': egg,
        'hatchAt': hatchAt?.toIso8601String(),
        'birthday': birthday,
      },
    );
    await addMemory(
      companionIds: [rec.id],
      kind: egg == 'none' ? 'adopt' : 'hatch',
      title: egg == 'none'
          ? 'Adopted ${name.trim()}'
          : '${name.trim()} hatched',
      at: hatchAt ?? now,
    );
    return rec;
  }

  Future<void> save(
    Companion c,
    Map<String, Object?> changes, {
    String? title,
    String? body,
  }) => _t.save(
    c.r.copyWith(title: title ?? c.r.title, body: body ?? c.r.body).withFields({
      ...c.r.fields,
      ...changes,
      'v': companionSchemaVersion,
    }),
  );

  /// Ownership changes keep everything else — memories, outfits, history.
  Future<void> setOwners(Companion c, OwnerType type, List<String> owners) =>
      save(c, {
        'ownerType': type.name,
        'owners': type == OwnerType.system || type == OwnerType.none
            ? <String>[]
            : owners,
      });

  Future<void> hatchNow(Companion c) => save(c, {
    'hatchAt': DateTime.now().toIso8601String(),
    'adoptedAt': DateTime.now().toIso8601String(),
  });

  /// Deletes the companion and, if [withMemories], its memories,
  /// outfits and history. Shared photos keep the other companions.
  Future<void> delete(Companion c, {bool withMemories = true}) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    for (final r in all) {
      if (r.parentId != c.id) continue;
      if (r.kind == TrackerKind.companionOutfit ||
          (withMemories &&
              (r.kind == TrackerKind.companionInteraction ||
                  r.kind == TrackerKind.companionMemory)))
        await _t.delete(r.id);
    }
    if (withMemories) {
      for (final r in all.where(
        (r) =>
            r.kind == TrackerKind.companionMemory &&
            _strs(r.fields['companions']).contains(c.id),
      )) {
        final rest = _strs(r.fields['companions'])..remove(c.id);
        if (rest.isEmpty) {
          await _t.delete(r.id);
        } else {
          await _t.save(
            r.copyWith(parentId: rest.first).withFields({
              ...r.fields,
              'companions': rest,
            }),
          );
        }
      }
    }
    await _t.delete(c.id);
  }

  /// Records an interaction and returns its flavour text.
  Future<String> interact(Companion c, String kind, {String? by}) async {
    final text = companionFlavor(c, kind);
    await _t.create(
      kind: TrackerKind.companionInteraction,
      parentId: c.id,
      memberId: by,
      body: text,
      occurredAt: DateTime.now(),
      fields: {'v': companionSchemaVersion, 'kind': kind, 'recordedBy': ?by},
    );
    return text;
  }

  Future<TrackerRecord> addMemory({
    required List<String> companionIds,
    required String kind,
    String title = '',
    String caption = '',
    PhotoScene? scene,
    String? media,
    DateTime? at,
    String? by,
  }) => _t.create(
    kind: TrackerKind.companionMemory,
    parentId: companionIds.firstOrNull,
    title: title,
    body: caption,
    memberId: by,
    occurredAt: at ?? DateTime.now(),
    fields: {
      'v': companionSchemaVersion,
      'kind': kind,
      'companions': companionIds,
      'scene': scene?.toJson(),
      'media': media,
    },
  );

  Future<void> deleteMemory(String id) => _t.delete(id);

  Future<void> saveOutfit(Companion c, String name, CompanionLook look) async {
    final rec = await _t.create(
      kind: TrackerKind.companionOutfit,
      parentId: c.id,
      title: name.trim(),
      fields: {'v': companionSchemaVersion, 'look': look.toJson()},
    );
    await save(c, {'outfit': rec.id});
  }

  Future<void> wearOutfit(Companion c, CompanionOutfit o) =>
      save(c, {'look': o.look.toJson(), 'outfit': o.r.id});
  Future<void> deleteOutfit(CompanionOutfit o) => _t.delete(o.r.id);

  Future<TrackerRecord> saveCustomSpecies({
    required String name,
    required String base,
    String? media,
  }) => _t.create(
    kind: TrackerKind.companionSpecies,
    title: name.trim(),
    fields: {'v': companionSchemaVersion, 'base': base, 'image': media},
  );

  Future<TrackerRecord> createHabitat(String env, {String name = ''}) =>
      _t.create(
        kind: TrackerKind.companionHabitat,
        title: name,
        fields: {
          'v': companionSchemaVersion,
          'env': env,
          'time': 'auto',
          'weather': 'clear',
          'lighting': 'soft',
          'items': <Object?>[],
        },
      );

  Future<void> saveHabitat(
    Habitat h,
    Map<String, Object?> changes, {
    String? title,
  }) => _t.save(
    h.r.copyWith(title: title ?? h.r.title).withFields({
      ...h.r.fields,
      ...changes,
      'v': companionSchemaVersion,
    }),
  );

  Future<void> deleteHabitat(Habitat h) async {
    for (final c
        in ref.read(companionsProvider).where((c) => c.habitatId == h.id)) {
      await save(c, {'habitat': null});
    }
    await _t.delete(h.id);
  }

  Future<void> saveSettings(CompanionSettings s) async {
    if (s.record == null) {
      await _t.create(
        kind: TrackerKind.companionSettings,
        fields: s.toFields(),
      );
    } else {
      await _t.save(s.record!.withFields(s.toFields()));
    }
  }
}

final companionActionsProvider = Provider<CompanionActions>(
  CompanionActions.new,
);
