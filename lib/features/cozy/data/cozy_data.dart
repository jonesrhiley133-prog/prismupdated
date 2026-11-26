import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Shared Cozy data. Everything is stored as tracker records so it syncs
/// and can be reset from Settings › Features like the rest of Prism.

List<TrackerRecord> _kind(Ref ref, String kind) =>
    ref.watch(trackerKindProvider(kind)).value ?? const <TrackerRecord>[];

List<String> strList(Object? v) => [
  for (final x in (v as List?) ?? const []) '$x',
];
Map<String, List<String>> reactionsOf(TrackerRecord r) => {
  for (final e in ((r.fields['reactions'] as Map?) ?? const {}).entries)
    '${e.key}': strList(e.value),
};

// ---------------------------------------------------------------------------
// Lounge settings
// ---------------------------------------------------------------------------

class CozySettings {
  const CozySettings({
    this.record,
    this.name = '',
    this.emoji = '☕',
    this.showQuote = true,
    this.showAffirmation = true,
    this.showQuestion = true,
    this.showWishlist = true,
  });
  final TrackerRecord? record;
  final String name;
  final String emoji;
  final bool showQuote, showAffirmation, showQuestion, showWishlist;

  Map<String, Object?> toFields() => {
    'name': name,
    'emoji': emoji,
    'quote': showQuote,
    'affirmation': showAffirmation,
    'question': showQuestion,
    'wishlist': showWishlist,
  };

  static CozySettings of(TrackerRecord? r) => CozySettings(
    record: r,
    name: '${r?.fields['name'] ?? ''}',
    emoji: '${r?.fields['emoji'] ?? '☕'}',
    showQuote: r?.fields['quote'] != false,
    showAffirmation: r?.fields['affirmation'] != false,
    showQuestion: r?.fields['question'] != false,
    showWishlist: r?.fields['wishlist'] != false,
  );
}

final cozySettingsProvider = Provider<CozySettings>(
  (ref) => CozySettings.of(_kind(ref, TrackerKind.cozySettings).firstOrNull),
);

// ---------------------------------------------------------------------------
// Posts, letters, gifts, plants, rooms, lists, doodles
// ---------------------------------------------------------------------------

/// Lounge posts, newest first. `fields.room` set = posted in a room.
final cozyPostsProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      [..._kind(ref, TrackerKind.cozyPost)]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
);

class Letter {
  Letter(this.r);
  final TrackerRecord r;
  String? get from => r.memberId;
  List<String> get to => strList(r.fields['to']);
  String get subject => r.title;
  String get body => r.body ?? '';
  String get stationery => '${r.fields['stationery'] ?? 'plain'}';
  bool get anonymous => r.fields['anonymous'] == true;
  bool get draft => r.fields['draft'] == true;
  DateTime? get deliverAt =>
      DateTime.tryParse('${r.fields['deliverAt'] ?? ''}');
  bool get delivered =>
      !draft && (deliverAt == null || !deliverAt!.isAfter(DateTime.now()));
  List<String> get readBy => strList(r.fields['read']);
  List<String> get favoritedBy => strList(r.fields['fav']);
  Map<String, List<String>> get reactions => reactionsOf(r);
  String? get mood => r.fields['mood'] as String?;
  DateTime get when => deliverAt ?? r.createdAt;
}

final lettersProvider = Provider<List<Letter>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.cozyLetter)) Letter(r)]
        ..sort((a, b) => b.when.compareTo(a.when)),
);

class Gift {
  Gift(this.r);
  final TrackerRecord r;
  String? get from => r.memberId;
  String? get to => r.fields['to'] as String?;
  String get emoji => '${r.fields['emoji'] ?? '🎁'}';
  String get name => r.title;
  String get message => r.body ?? '';
  bool get opened => r.fields['opened'] == true;
  bool get surprise => r.fields['surprise'] == true;
}

final giftsProvider = Provider<List<Gift>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.cozyGift)) Gift(r)]
        ..sort((a, b) => b.r.createdAt.compareTo(a.r.createdAt)),
);

class Plant {
  Plant(this.r);
  final TrackerRecord r;
  String get name => r.title;
  String get species => '${r.fields['species'] ?? 'sprout'}';
  String? get planter => r.memberId;
  List<(String?, DateTime)> get waterings => [
    for (final w in (r.fields['water'] as List?) ?? const [])
      if (w is Map)
        (w['by'] as String?, DateTime.tryParse('${w['at']}') ?? r.createdAt),
  ];
  DateTime get lastWatered => waterings.isEmpty
      ? r.createdAt
      : waterings.map((w) => w.$2).reduce((a, b) => a.isAfter(b) ? a : b);

  /// 0 seed · 1 sprout · 2 young · 3 grown · 4 blooming. Never goes down.
  int get stage => switch (waterings.length) {
    0 => 0,
    < 3 => 1,
    < 7 => 2,
    < 14 => 3,
    _ => 4,
  };

  /// Thirsty after two days — it just droops a little; plants never die.
  bool get thirsty => DateTime.now().difference(lastWatered).inHours > 48;
}

const plantSpecies = <String, (String, List<String>)>{
  'sprout': ('Sprout', ['🌰', '🌱', '🌿', '🪴', '🪴']),
  'flower': ('Flower', ['🌰', '🌱', '🌿', '🌷', '🌸']),
  'sunflower': ('Sunflower', ['🌰', '🌱', '🌿', '🌻', '🌻']),
  'tree': ('Tree', ['🌰', '🌱', '🌿', '🌳', '🌳']),
  'cactus': ('Cactus', ['🌰', '🌱', '🌵', '🌵', '🌵']),
  'rose': ('Rose', ['🌰', '🌱', '🌿', '🥀', '🌹']),
  'blossom': ('Blossom tree', ['🌰', '🌱', '🌿', '🌳', '🌸']),
  'herb': ('Herbs', ['🌰', '🌱', '🌿', '🌿', '🍃']),
  'mushroom': ('Mushroom', ['🌰', '🟤', '🍄', '🍄', '🍄‍🟫']),
  'lotus': ('Lotus', ['🌰', '🌱', '🪷', '🪷', '🪷']),
};

final plantsProvider = Provider<List<Plant>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.cozyPlant)) Plant(r)]
        ..sort((a, b) => a.r.createdAt.compareTo(b.r.createdAt)),
);

class Room {
  Room(this.r);
  final TrackerRecord r;
  String get name => r.title;
  String get emoji => '${r.fields['emoji'] ?? '🏠'}';
  String? get owner => r.memberId;

  /// public · private · shared · subsystem
  String get access => '${r.fields['access'] ?? 'public'}';
  List<String> get members => strList(r.fields['members']);
  String? get subsystemId => r.fields['subsystem'] as String?;
  int? get color => (r.fields['color'] as num?)?.toInt();
  String get description => r.body ?? '';
}

final roomsProvider = Provider<List<Room>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.cozyRoom)) Room(r)]
        ..sort((a, b) => a.r.createdAt.compareTo(b.r.createdAt)),
);

/// Who may open [room]: everyone for public rooms; otherwise the owner,
/// listed members, or members of the linked subsystem.
final roomAllowedProvider = Provider.family<Set<String>?, String>((
  ref,
  roomId,
) {
  final room = ref
      .watch(roomsProvider)
      .where((x) => x.r.id == roomId)
      .firstOrNull;
  if (room == null || room.access == 'public') return null;
  final ids = <String>{?room.owner, ...room.members};
  if (room.access == 'subsystem' && room.subsystemId != null) {
    ids.addAll([
      for (final m in ref.watch(subMembershipsProvider))
        if (m.subsystemId == room.subsystemId) m.memberId,
    ]);
  }
  return ids;
});

final roomItemsProvider = Provider.family<List<TrackerRecord>, String>(
  (ref, roomId) => [
    for (final r in _kind(ref, TrackerKind.cozyRoomItem))
      if (r.parentId == roomId) r,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
);

/// Items of one shared list (jar, capsule, shelf…), newest first.
final cozyListProvider = Provider.family<List<TrackerRecord>, String>(
  (ref, list) =>
      [
        for (final r in _kind(ref, TrackerKind.cozyListItem))
          if (r.fields['list'] == list) r,
      ]..sort(
        (a, b) => (b.occurredAt ?? b.createdAt).compareTo(
          a.occurredAt ?? a.createdAt,
        ),
      ),
);

final doodlesProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      [..._kind(ref, TrackerKind.cozyDoodle)]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
);

final comfortProvider = Provider<List<TrackerRecord>>(
  (ref) => _kind(ref, TrackerKind.cozyComfort),
);

/// Everyone who did anything in Cozy in the last week, most recent first.
final recentCozyParticipantsProvider = Provider<List<String>>((ref) {
  final since = DateTime.now().subtract(const Duration(days: 7));
  final all =
      [
            ..._kind(ref, TrackerKind.cozyPost),
            ..._kind(ref, TrackerKind.cozyLetter),
            ..._kind(ref, TrackerKind.cozyListItem),
            ..._kind(ref, TrackerKind.cozyDoodle),
            ..._kind(ref, TrackerKind.cozyGift),
          ]
          .where((r) => r.memberId != null && r.createdAt.isAfter(since))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final out = <String>[];
  for (final r in all) {
    if (!out.contains(r.memberId)) out.add(r.memberId!);
  }
  return out;
});

/// Who is "here" in Cozy right now: the fronter, if any. Never required.
final cozyMeProvider = Provider<String?>(
  (ref) => ref.watch(gamePlayerDefaultProvider),
);

class CozyActions {
  CozyActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord> post({
    required String body,
    String? memberId,
    String? room,
    String? starter,
    String? mood,
  }) => _t.create(
    kind: TrackerKind.cozyPost,
    body: body,
    memberId: memberId,
    occurredAt: DateTime.now(),
    fields: {'room': room, 'starter': starter, 'mood': mood},
  );

  Future<void> react(TrackerRecord r, String emoji, String who) {
    final map = reactionsOf(r);
    final list = [...?map[emoji]];
    list.contains(who) ? list.remove(who) : list.add(who);
    map[emoji] = list;
    map.removeWhere((_, v) => v.isEmpty);
    return _t.save(r.withFields({...r.fields, 'reactions': map}));
  }

  Future<void> toggleIn(TrackerRecord r, String field, String who) {
    final list = strList(r.fields[field]);
    list.contains(who) ? list.remove(who) : list.add(who);
    return _t.save(r.withFields({...r.fields, field: list}));
  }

  Future<void> setFields(TrackerRecord r, Map<String, Object?> f) =>
      _t.save(r.withFields({...r.fields, ...f}));

  Future<TrackerRecord> addListItem(
    String list, {
    required String title,
    String? body,
    String? memberId,
    Map<String, Object?> fields = const {},
    DateTime? when,
  }) => _t.create(
    kind: TrackerKind.cozyListItem,
    title: title,
    body: body,
    memberId: memberId,
    occurredAt: when ?? DateTime.now(),
    fields: {'list': list, ...fields},
  );

  Future<void> saveSettings(CozySettings s) async {
    if (s.record == null) {
      await _t.create(kind: TrackerKind.cozySettings, fields: s.toFields());
    } else {
      await _t.save(s.record!.withFields(s.toFields()));
    }
  }

  Future<void> water(Plant p, String? who) => _t.save(
    p.r.withFields({
      ...p.r.fields,
      'water': [
        ...((p.r.fields['water'] as List?) ?? const []),
        {'by': who, 'at': DateTime.now().toIso8601String()},
      ],
    }),
  );

  Future<void> delete(TrackerRecord r) => _t.delete(r.id);

  /// Copies something cozy into the Journal.
  Future<void> toJournal({
    required String title,
    required String body,
    String? memberId,
  }) => _t.create(
    kind: TrackerKind.journalEntry,
    title: title,
    body: body,
    memberId: memberId,
    occurredAt: DateTime.now(),
    tags: const ['cozy'],
  );
}

final cozyActionsProvider = Provider<CozyActions>(CozyActions.new);

/// Optional mood tag (chosen, never inferred).
const cozyMoods = ['😊', '😌', '🥰', '😴', '🤔', '😢', '😤', '🥳', '😶'];

/// Day-stable pick from a list.
T dailyPick<T>(List<T> list, {int salt = 0}) {
  final d = DateTime.now();
  return list[((d.year * 372 + d.month * 31 + d.day) * 7 + salt) % list.length];
}
