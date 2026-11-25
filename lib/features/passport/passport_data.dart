import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/features/passport/stamp_art.dart';
import 'package:prism_plurality/features/smart_notifications/notify_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Prism Passport: a souvenir book of experiences. Separate from
/// Achievements — achievements recognise accomplishments, passports keep
/// experiences. Everything is a synced, versioned tracker record.
const passportSchemaVersion = 1;

List<String> _strs(Object? v) => [
  for (final x in (v as List?) ?? const []) '$x',
];
double _d(Object? v, double d) => (v as num?)?.toDouble() ?? d;

const passportTypes = <String, (String, String)>{
  'personal': ('Personal passport', '🪪'),
  'system': ('System passport', '🌈'),
  'subsystem': ('Subsystem passport', '🫂'),
  'shared': ('Shared passport', '🤝'),
  'travel': ('Travel passport', '✈️'),
  'creative': ('Creative passport', '🎨'),
  'seasonal': ('Seasonal passport', '🍂'),
  'gaming': ('Gaming passport', '🎮'),
  'friendship': ('Friendship passport', '💌'),
  'custom': ('Custom passport', '✨'),
};

const passportPageTypes = <String, (String, String)>{
  'stamps': ('Stamp collection', '🔖'),
  'photos': ('Photographs', '📷'),
  'journal': ('Journal', '📝'),
  'memory': ('Memory', '💭'),
  'event': ('Event', '🎟️'),
  'timeline': ('Timeline', '🗓️'),
  'stickers': ('Stickers', '🌟'),
  'collage': ('Collage', '🧩'),
  'companion': ('Companion', '🐾'),
  'travel': ('Travel', '🗺️'),
  'creative': ('Creative project', '🖌️'),
  'blank': ('Blank page', '📄'),
};

const coverMaterials = [
  'leather',
  'linen',
  'velvet',
  'paper',
  'kraft',
  'metallic',
  'holographic',
  'denim',
];
const coverBorders = [
  'none',
  'gold',
  'silver',
  'stitched',
  'ornate',
  'dotted',
  'double',
];
const passportFonts = ['serif', 'sans', 'rounded', 'mono', 'script'];
const paperTextures = [
  'plain',
  'dotted',
  'grid',
  'lined',
  'kraft',
  'watercolor',
  'linen',
];
const pageTransitions = ['flip', 'slide', 'fade', 'none'];

@immutable
class PassportCover {
  const PassportCover({
    this.material = 'leather',
    this.primary = 0xFF1E3A5F,
    this.secondary = 0xFFD4AF37,
    this.border = 'gold',
    this.symbol = '🌍',
    this.font = 'serif',
  });
  final String material;
  final int primary, secondary;
  final String border, symbol, font;
  Map<String, Object?> toJson() => {
    'material': material,
    'primary': primary,
    'secondary': secondary,
    'border': border,
    'symbol': symbol,
    'font': font,
  };
  static PassportCover fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    return PassportCover(
      material: coverMaterials.contains(j['material'])
          ? j['material'] as String
          : 'leather',
      primary: (j['primary'] as num?)?.toInt() ?? 0xFF1E3A5F,
      secondary: (j['secondary'] as num?)?.toInt() ?? 0xFFD4AF37,
      border: coverBorders.contains(j['border'])
          ? j['border'] as String
          : 'gold',
      symbol: '${j['symbol'] ?? '🌍'}',
      font: passportFonts.contains(j['font']) ? j['font'] as String : 'serif',
    );
  }

  PassportCover copyWith(Map<String, Object?> c) =>
      fromJson({...toJson(), ...c});
}

/// Ready-made looks. Every part can still be changed by hand.
const passportTemplates = <String, (String, PassportCover, int, String)>{
  'classic': ('Classic navy', PassportCover(), 0xFFFBF7EF, 'plain'),
  'forest': (
    'Forest leather',
    PassportCover(
      material: 'leather',
      primary: 0xFF2F4F3A,
      secondary: 0xFFE9D8A6,
      border: 'stitched',
      symbol: '🌲',
    ),
    0xFFF6F1E3,
    'kraft',
  ),
  'rose': (
    'Rose velvet',
    PassportCover(
      material: 'velvet',
      primary: 0xFF9D3C5B,
      secondary: 0xFFFFD6E2,
      border: 'ornate',
      symbol: '🌹',
      font: 'script',
    ),
    0xFFFFF6F8,
    'watercolor',
  ),
  'night': (
    'Starry night',
    PassportCover(
      material: 'linen',
      primary: 0xFF1D1F4A,
      secondary: 0xFFFFE08A,
      border: 'dotted',
      symbol: '🌙',
    ),
    0xFFF3F2FA,
    'dotted',
  ),
  'scrap': (
    'Kraft scrapbook',
    PassportCover(
      material: 'kraft',
      primary: 0xFFB08A5B,
      secondary: 0xFF3E2C1C,
      border: 'stitched',
      symbol: '📎',
      font: 'mono',
    ),
    0xFFF4EBDD,
    'grid',
  ),
  'holo': (
    'Holographic',
    PassportCover(
      material: 'holographic',
      primary: 0xFFB9A7FF,
      secondary: 0xFFFFFFFF,
      border: 'silver',
      symbol: '💿',
      font: 'rounded',
    ),
    0xFFFAF8FF,
    'plain',
  ),
  'game': (
    'Arcade',
    PassportCover(
      material: 'metallic',
      primary: 0xFF242A38,
      secondary: 0xFF5EEAD4,
      border: 'double',
      symbol: '🕹️',
      font: 'mono',
    ),
    0xFFF2F5F8,
    'grid',
  ),
};

class Passport {
  Passport(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.isEmpty ? 'Passport' : r.title;
  String get subtitle => '${r.fields['subtitle'] ?? ''}';
  String get type => '${r.fields['type'] ?? 'personal'}';
  OwnerType get ownerType =>
      OwnerType.values
          .where((o) => o.name == r.fields['ownerType'])
          .firstOrNull ??
      OwnerType.system;
  List<String> get owners => _strs(r.fields['owners']);
  PassportCover get cover => PassportCover.fromJson(r.fields['cover']);
  int get paper => (r.fields['paper'] as num?)?.toInt() ?? 0xFFFBF7EF;
  String get texture => '${r.fields['texture'] ?? 'plain'}';
  String get transition => '${r.fields['transition'] ?? 'flip'}';
  bool get openingAnimation => r.fields['opening'] != false;
  String get intro => r.body ?? '';
  String get visibility => '${r.fields['visibility'] ?? 'system'}';
  String get stampStyle => '${r.fields['stampStyle'] ?? 'ink'}';
  bool get favorite => r.flag('favorite');
  bool get pinned => r.isPinned;
  bool get archived => r.flag('archived');
  String get folder => '${r.fields['folder'] ?? ''}';
  int get order => r.sortOrder;
  DateTime? get lastOpened => DateTime.tryParse('${r.fields['opened'] ?? ''}');
}

class PassportPage {
  PassportPage(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get passportId => r.parentId ?? '';
  String get title => r.title;
  String get type => '${r.fields['type'] ?? 'blank'}';
  int get order => r.sortOrder;
  bool get manual => r.fields['layout'] == 'manual';
  int? get background => (r.fields['background'] as num?)?.toInt();
  List<String> get attachments => _strs(r.fields['attachments']);
  String get note => r.body ?? '';
}

/// Something placed on a page.
class PassportElement {
  PassportElement(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get pageId => r.parentId ?? '';
  String get type =>
      '${r.fields['type'] ?? 'sticker'}'; // stamp, photo, sticker, text, attachment, companion
  double get x => _d(r.fields['x'], 0.5).clamp(0, 1);
  double get y => _d(r.fields['y'], 0.5).clamp(0, 1);
  double get scale => _d(r.fields['scale'], 1).clamp(0.3, 3);
  double get rotation => _d(r.fields['rotation'], 0);
  String? get stampId => r.fields['stamp'] as String?;
  String? get media => r.fields['media'] as String?;
  String get emoji => '${r.fields['emoji'] ?? '⭐'}';
  String get text => r.body ?? '';
  String? get refKey => r.fields['ref'] as String?;
  int get color => (r.fields['color'] as num?)?.toInt() ?? 0xFF2B2B33;
  int get order => r.sortOrder;
}

class PassportStamp {
  PassportStamp(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get passportId => r.parentId ?? '';
  String get title => r.title;
  String get category => '${r.fields['category'] ?? 'custom'}';
  StampDesign get design => StampDesign.fromJson(r.fields['design']);
  DateTime get at => r.occurredAt ?? r.createdAt;
  String get location => '${r.fields['location'] ?? ''}';
  String get note => r.body ?? '';
  List<String> get attachments => _strs(r.fields['attachments']);
  String? get suggestionKey => r.fields['suggestion'] as String?;
}

class StampTemplate {
  StampTemplate(this.r);
  final TrackerRecord r;
  String get name => r.title.isEmpty ? 'Stamp' : r.title;
  StampDesign get design => StampDesign.fromJson(r.fields['design']);
  String get category => '${r.fields['category'] ?? 'custom'}';
}

class PassportSettings {
  const PassportSettings({
    this.record,
    this.suggest = const {
      'personal': true,
      'companion': true,
      'system': true,
      'entertainment': true,
      'creative': true,
      'places': true,
    },
    this.dismissed = const {},
    this.view = 'grid',
    this.folders = const [],
  });
  final TrackerRecord? record;

  /// Suggestion categories that are on. Journal, health and location
  /// history are never suggested automatically.
  final Map<String, bool> suggest;
  final Set<String> dismissed;
  final String view;
  final List<String> folders;

  Map<String, Object?> toFields() => {
    'v': passportSchemaVersion,
    'suggest': suggest,
    'dismissed': dismissed.toList(),
    'view': view,
    'folders': folders,
  };
  static PassportSettings of(TrackerRecord? r) {
    if (r == null) return const PassportSettings();
    final f = r.fields;
    return PassportSettings(
      record: r,
      suggest: f['suggest'] is Map
          ? {
              for (final e in (f['suggest'] as Map).entries)
                '${e.key}': e.value == true,
            }
          : const PassportSettings().suggest,
      dismissed: _strs(f['dismissed']).toSet(),
      view: '${f['view'] ?? 'grid'}',
      folders: _strs(f['folders']),
    );
  }

  PassportSettings copyWith({
    Map<String, bool>? suggest,
    Set<String>? dismissed,
    String? view,
    List<String>? folders,
  }) => PassportSettings(
    record: record,
    suggest: suggest ?? this.suggest,
    dismissed: dismissed ?? this.dismissed,
    view: view ?? this.view,
    folders: folders ?? this.folders,
  );
}

// ── Providers ────────────────────────────────────────────────────────────

List<TrackerRecord> _kind(Ref ref, String kind) =>
    ref.watch(trackerKindProvider(kind)).value ?? const <TrackerRecord>[];

final passportsProvider = Provider<List<Passport>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.passport)) Passport(r)]..sort(
        (a, b) => a.order != b.order
            ? a.order.compareTo(b.order)
            : a.r.createdAt.compareTo(b.r.createdAt),
      ),
);
final passportByIdProvider = Provider.family<Passport?, String>(
  (ref, id) =>
      ref.watch(passportsProvider).where((p) => p.id == id).firstOrNull,
);
final passportPagesProvider = Provider.family<List<PassportPage>, String>(
  (ref, id) => [
    for (final r in _kind(ref, TrackerKind.passportPage))
      if (r.parentId == id) PassportPage(r),
  ]..sort((a, b) => a.order.compareTo(b.order)),
);
final pageElementsProvider = Provider.family<List<PassportElement>, String>(
  (ref, pageId) => [
    for (final r in _kind(ref, TrackerKind.passportElement))
      if (r.parentId == pageId) PassportElement(r),
  ]..sort((a, b) => a.order.compareTo(b.order)),
);
final allStampsProvider = Provider<List<PassportStamp>>(
  (ref) =>
      [for (final r in _kind(ref, TrackerKind.passportStamp)) PassportStamp(r)]
        ..sort((a, b) => a.at.compareTo(b.at)),
);
final passportStampsProvider = Provider.family<List<PassportStamp>, String>(
  (ref, id) => [
    for (final s in ref.watch(allStampsProvider))
      if (s.passportId == id) s,
  ],
);
final stampByIdProvider = Provider.family<PassportStamp?, String>(
  (ref, id) =>
      ref.watch(allStampsProvider).where((s) => s.id == id).firstOrNull,
);
final stampTemplatesProvider = Provider<List<StampTemplate>>(
  (ref) => [
    for (final r in _kind(ref, TrackerKind.passportStampTemplate))
      StampTemplate(r),
  ],
);
final passportSettingsProvider = Provider<PassportSettings>((ref) {
  final rows = _kind(ref, TrackerKind.passportSettings);
  return PassportSettings.of(
    rows.isEmpty
        ? null
        : (rows.toList()..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt)))
              .first,
  );
});

// ── Suggestions ──────────────────────────────────────────────────────────

/// A stamp Prism suggests. Nothing is added until the user accepts it.
@immutable
class StampSuggestion {
  const StampSuggestion({
    required this.key,
    required this.category,
    required this.title,
    required this.design,
    required this.at,
    this.attachments = const [],
  });
  final String key;
  final String category;
  final String title;
  final StampDesign design;
  final DateTime at;
  final List<String> attachments;
}

String stampDate(DateTime d) =>
    DateFormat('d MMM yyyy').format(d).toUpperCase();

/// Builds suggestions from recent, non-sensitive activity. Journal
/// entries, health records and location history are never used.
@visibleForTesting
List<StampSuggestion> buildSuggestions({
  required DateTime now,
  required PassportSettings settings,
  required Set<String> taken,
  required List<Member> members,
  required List<Companion> companions,
  required List<CompanionMemory> memories,
  required List<TrackerRecord> games,
  required List<TrackerRecord> creative,
  required List<(String id, String title, DateTime at)> events,
  String? systemBirthday,
  bool preferDisplay = false,
}) {
  final out = <StampSuggestion>[];
  final since = now.subtract(const Duration(days: 30));
  bool on(String c) => settings.suggest[c] ?? false;
  void add(StampSuggestion s) {
    if (!taken.contains(s.key) && !settings.dismissed.contains(s.key))
      out.add(s);
  }

  if (on('personal')) {
    for (final m in members) {
      final b = parseBirthday(m.birthday);
      if (b == null) continue;
      var day = DateTime(now.year, b.month, b.day);
      if (day.isAfter(now)) day = DateTime(now.year - 1, b.month, b.day);
      if (now.difference(day).inDays > 14) continue;
      final name = m.effectiveName(preferDisplayName: preferDisplay);
      add(
        StampSuggestion(
          key: 'bday:${m.id}:${day.year}',
          category: 'personal',
          title: '$name\'s birthday',
          at: day,
          design: defaultStampFor(
            'personal',
            text: '$name\'s birthday',
            icon: '🎂',
            date: stampDate(day),
          ),
          attachments: ['member:${m.id}'],
        ),
      );
    }
  }
  if (on('system') && systemBirthday != null) {
    final b = parseAnyBirthday(systemBirthday);
    if (b != null) {
      var day = DateTime(now.year, b.month, b.day);
      if (day.isAfter(now)) day = DateTime(now.year - 1, b.month, b.day);
      if (now.difference(day).inDays <= 14)
        add(
          StampSuggestion(
            key: 'sysbday:${day.year}',
            category: 'system',
            title: 'System anniversary',
            at: day,
            design: defaultStampFor(
              'system',
              text: 'System anniversary',
              icon: '💞',
              date: stampDate(day),
            ),
          ),
        );
    }
  }
  if (on('companion')) {
    for (final m in memories.where((m) => m.at.isAfter(since))) {
      final c = companions
          .where((c) => m.companionIds.contains(c.id))
          .firstOrNull;
      if (c == null) continue;
      switch (m.kind) {
        case 'adopt':
          add(
            StampSuggestion(
              key: 'adopt:${c.id}',
              category: 'companion',
              title: 'Adopted ${c.name}',
              at: m.at,
              design: defaultStampFor(
                'companion',
                text: 'Adopted ${c.name}',
                icon: c.species.emoji,
                date: stampDate(m.at),
              ),
              attachments: ['rec:${c.id}'],
            ),
          );
        case 'hatch':
          add(
            StampSuggestion(
              key: 'hatch:${c.id}',
              category: 'companion',
              title: '${c.name} hatched',
              at: m.at,
              design: defaultStampFor(
                'companion',
                text: '${c.name} hatched',
                icon: '🥚',
                date: stampDate(m.at),
              ).copyWith({'shape': 'oval'}),
              attachments: ['rec:${c.id}'],
            ),
          );
        case 'photo':
          add(
            StampSuggestion(
              key: 'photo:${m.id}',
              category: 'companion',
              title: m.title.isEmpty ? 'Photo with ${c.name}' : m.title,
              at: m.at,
              design: defaultStampFor(
                'companion',
                text: 'Photo day',
                icon: '📸',
                date: stampDate(m.at),
              ),
              attachments: ['rec:${m.id}'],
            ),
          );
      }
    }
  }
  if (on('entertainment')) {
    final recent = games
        .where((g) => (g.occurredAt ?? g.createdAt).isAfter(since))
        .toList();
    final byGame = <String, List<TrackerRecord>>{};
    for (final g in recent) {
      byGame.putIfAbsent('${g.fields['game'] ?? g.title}', () => []).add(g);
    }
    for (final e in byGame.entries.take(6)) {
      final first = e.value.first;
      final at = first.occurredAt ?? first.createdAt;
      final name = first.title.isNotEmpty ? first.title : e.key;
      add(
        StampSuggestion(
          key: 'game:${e.key}:${at.year}-${at.month}',
          category: 'entertainment',
          title: 'Played $name',
          at: at,
          design: defaultStampFor(
            'entertainment',
            text: name,
            icon: '🎮',
            date: stampDate(at),
          ),
        ),
      );
    }
  }
  if (on('creative')) {
    for (final r in creative.where((r) => r.createdAt.isAfter(since)).take(6)) {
      add(
        StampSuggestion(
          key: 'create:${r.id}',
          category: 'creative',
          title: r.title.isEmpty ? 'Made something' : 'Made “${r.title}”',
          at: r.createdAt,
          design: defaultStampFor(
            'creative',
            text: r.title.isEmpty ? 'Created' : r.title,
            icon: '🎨',
            date: stampDate(r.createdAt),
          ),
          attachments: ['rec:${r.id}'],
        ),
      );
    }
  }
  if (on('places')) {
    for (final (id, title, at)
        in events
            .where((e) => e.$3.isAfter(since) && !e.$3.isAfter(now))
            .take(8)) {
      add(
        StampSuggestion(
          key: 'event:$id',
          category: 'places',
          title: title,
          at: at,
          design: defaultStampFor(
            'places',
            text: title,
            icon: '🎟️',
            date: stampDate(at),
          ),
          attachments: ['event:$id'],
        ),
      );
    }
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

final stampSuggestionsProvider = Provider<List<StampSuggestion>>((ref) {
  final settings = ref.watch(passportSettingsProvider);
  final taken = {
    for (final s in ref.watch(allStampsProvider)) ?s.suggestionKey,
  };
  final cal = [
    for (final e
        in ref.watch(calendarEventsProvider).value ?? const <CalendarEvent>[])
      (e.id, e.title, e.startAt),
  ];
  return buildSuggestions(
    now: DateTime.now(),
    settings: settings,
    taken: taken,
    members: ref.watch(userVisibleMembersProvider).value ?? const [],
    companions: ref.watch(companionsProvider),
    memories: ref.watch(companionMemoriesProvider),
    games:
        ref.watch(trackerKindProvider(TrackerKind.gameResult)).value ??
        const [],
    creative: [
      ...?ref.watch(trackerKindProvider(TrackerKind.cozyDoodle)).value,
      ...?ref.watch(trackerKindProvider(TrackerKind.scrapPage)).value,
      ...?ref.watch(trackerKindProvider(TrackerKind.gameProject)).value,
    ],
    events: cal,
    systemBirthday: ref.watch(notifySettingsProvider).systemBirthday,
    preferDisplay: ref.watch(memberNamePreferDisplayProvider),
  );
});

// ── Actions ──────────────────────────────────────────────────────────────

class PassportActions {
  PassportActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<TrackerRecord> create({
    required String name,
    String subtitle = '',
    String type = 'personal',
    OwnerType ownerType = OwnerType.system,
    List<String> owners = const [],
    PassportCover cover = const PassportCover(),
    int paper = 0xFFFBF7EF,
    String texture = 'plain',
    String transition = 'flip',
    bool opening = true,
    String intro = '',
    String visibility = 'system',
  }) async {
    final order = ref.read(passportsProvider).length;
    final rec = await _t.create(
      kind: TrackerKind.passport,
      title: name.trim(),
      body: intro.trim(),
      sortOrder: order,
      fields: {
        'v': passportSchemaVersion,
        'subtitle': subtitle.trim(),
        'type': type,
        'ownerType': ownerType.name,
        'owners': owners,
        'cover': cover.toJson(),
        'paper': paper,
        'texture': texture,
        'transition': transition,
        'opening': opening,
        'visibility': visibility,
      },
    );
    // Start with a stamp page so the first stamp has a home.
    await addPage(rec.id, 'stamps', title: 'Stamps');
    return rec;
  }

  Future<void> save(
    Passport p,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    bool? pinned,
    int? order,
  }) => _t.save(
    p.r
        .copyWith(
          title: title ?? p.r.title,
          body: body ?? p.r.body,
          isPinned: pinned ?? p.r.isPinned,
          sortOrder: order ?? p.r.sortOrder,
        )
        .withFields({...p.r.fields, ...changes, 'v': passportSchemaVersion}),
  );

  Future<void> markOpened(Passport p) =>
      save(p, {'opened': DateTime.now().toIso8601String()});

  Future<void> delete(Passport p) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    final pageIds = {
      for (final r in all)
        if (r.kind == TrackerKind.passportPage && r.parentId == p.id) r.id,
    };
    for (final r in all) {
      final mine =
          (r.kind == TrackerKind.passportPage && r.parentId == p.id) ||
          (r.kind == TrackerKind.passportElement &&
              pageIds.contains(r.parentId)) ||
          (r.kind == TrackerKind.passportStamp && r.parentId == p.id);
      if (mine) await _t.delete(r.id, children: false);
    }
    await _t.delete(p.id, children: false);
  }

  Future<TrackerRecord> addPage(
    String passportId,
    String type, {
    String title = '',
    int? at,
  }) async {
    final pages = ref.read(passportPagesProvider(passportId));
    final order = at ?? (pages.isEmpty ? 0 : pages.last.order + 1);
    return _t.create(
      kind: TrackerKind.passportPage,
      parentId: passportId,
      title: title.isEmpty ? passportPageTypes[type]?.$1 ?? 'Page' : title,
      sortOrder: order,
      fields: {
        'v': passportSchemaVersion,
        'type': type,
        'layout': type == 'collage' || type == 'stickers' ? 'manual' : 'auto',
      },
    );
  }

  Future<void> savePage(
    PassportPage p,
    Map<String, Object?> changes, {
    String? title,
    String? body,
    int? order,
  }) => _t.save(
    p.r
        .copyWith(
          title: title ?? p.r.title,
          body: body ?? p.r.body,
          sortOrder: order ?? p.r.sortOrder,
        )
        .withFields({...p.r.fields, ...changes, 'v': passportSchemaVersion}),
  );

  Future<void> deletePage(PassportPage p) async {
    for (final e in ref.read(pageElementsProvider(p.id))) {
      await _t.delete(e.id, children: false);
    }
    await _t.delete(p.id, children: false);
  }

  Future<void> duplicatePage(PassportPage p) async {
    final copy = await addPage(
      p.passportId,
      p.type,
      title: '${p.title} (copy)',
    );
    await _t.save(copy.copyWith(body: p.r.body).withFields({...p.r.fields}));
    for (final e in ref.read(pageElementsProvider(p.id))) {
      await _t.create(
        kind: TrackerKind.passportElement,
        parentId: copy.id,
        body: e.r.body,
        sortOrder: e.order,
        fields: {...e.r.fields},
      );
    }
  }

  /// Moves [p] one place earlier/later by swapping orders.
  Future<void> movePage(PassportPage p, int delta) async {
    final pages = ref.read(passportPagesProvider(p.passportId));
    final i = pages.indexWhere((x) => x.id == p.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= pages.length) return;
    // Normalise orders so swaps are always visible.
    for (var k = 0; k < pages.length; k++) {
      final want = k == i ? j : (k == j ? i : k);
      if (pages[k].order != want)
        await savePage(pages[k], const {}, order: want);
    }
  }

  Future<TrackerRecord> addElement(
    String pageId,
    String type, {
    double x = 0.5,
    double y = 0.5,
    String? stampId,
    String? media,
    String? emoji,
    String text = '',
    String? refKey,
    double scale = 1,
    double rotation = 0,
    int? color,
  }) {
    final n = ref.read(pageElementsProvider(pageId)).length;
    return _t.create(
      kind: TrackerKind.passportElement,
      parentId: pageId,
      body: text,
      sortOrder: n,
      fields: {
        'v': passportSchemaVersion,
        'type': type,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'stamp': stampId,
        'media': media,
        'emoji': emoji,
        'ref': refKey,
        'color': color,
      },
    );
  }

  Future<void> moveElement(
    PassportElement e, {
    double? x,
    double? y,
    double? scale,
    double? rotation,
    String? text,
  }) => _t.save(
    e.r.copyWith(body: text ?? e.r.body).withFields({
      ...e.r.fields,
      'x': x ?? e.x,
      'y': y ?? e.y,
      'scale': scale ?? e.scale,
      'rotation': rotation ?? e.rotation,
    }),
  );

  Future<void> deleteElement(PassportElement e) =>
      _t.delete(e.id, children: false);

  /// Adds a stamp to a passport and places it on [pageId] (or the first
  /// stamp page, created if needed).
  Future<TrackerRecord> addStamp(
    String passportId, {
    required String title,
    required String category,
    required StampDesign design,
    DateTime? at,
    String location = '',
    String note = '',
    List<String> attachments = const [],
    String? suggestionKey,
    String? pageId,
  }) async {
    final rec = await _t.create(
      kind: TrackerKind.passportStamp,
      parentId: passportId,
      title: title.trim(),
      body: note.trim(),
      occurredAt: at ?? DateTime.now(),
      fields: {
        'v': passportSchemaVersion,
        'category': category,
        'design': design.toJson(),
        'location': location.trim(),
        'attachments': attachments,
        'suggestion': suggestionKey,
      },
    );
    var target = pageId;
    if (target == null) {
      final pages = ref.read(passportPagesProvider(passportId));
      target =
          pages.where((p) => p.type == 'stamps').firstOrNull?.id ??
          (await addPage(passportId, 'stamps', title: 'Stamps')).id;
    }
    final placed = ref.read(pageElementsProvider(target)).length;
    await addElement(
      target,
      'stamp',
      stampId: rec.id,
      x: 0.2 + (placed % 3) * 0.3,
      y: 0.18 + (placed ~/ 3 % 4) * 0.22,
      rotation: design.rotation,
    );
    return rec;
  }

  Future<void> saveStamp(
    PassportStamp s, {
    String? title,
    StampDesign? design,
    DateTime? at,
    String? location,
    String? note,
    List<String>? attachments,
  }) => _t.save(
    s.r
        .copyWith(
          title: title ?? s.r.title,
          body: note ?? s.r.body,
          occurredAt: at ?? s.r.occurredAt,
        )
        .withFields({
          ...s.r.fields,
          'design': (design ?? s.design).toJson(),
          'location': location ?? s.location,
          'attachments': attachments ?? s.attachments,
        }),
  );

  Future<void> deleteStamp(PassportStamp s) async {
    final all = await ref.read(trackerRecordRepositoryProvider).getAll();
    for (final r in all.where(
      (r) => r.kind == TrackerKind.passportElement && r.fields['stamp'] == s.id,
    )) {
      await _t.delete(r.id, children: false);
    }
    await _t.delete(s.id, children: false);
  }

  Future<TrackerRecord> saveTemplate(
    String name,
    StampDesign d, {
    String category = 'custom',
  }) => _t.create(
    kind: TrackerKind.passportStampTemplate,
    title: name.trim(),
    fields: {
      'v': passportSchemaVersion,
      'design': d.toJson(),
      'category': category,
    },
  );
  Future<void> deleteTemplate(StampTemplate t) =>
      _t.delete(t.r.id, children: false);

  Future<void> saveSettings(PassportSettings s) async {
    if (s.record == null) {
      await _t.create(kind: TrackerKind.passportSettings, fields: s.toFields());
    } else {
      await _t.save(s.record!.withFields(s.toFields()));
    }
  }

  Future<void> dismiss(String key) {
    final s = ref.read(passportSettingsProvider);
    return saveSettings(s.copyWith(dismissed: {...s.dismissed, key}));
  }

  Future<void> accept(StampSuggestion s, String passportId) => addStamp(
    passportId,
    title: s.title,
    category: s.category,
    design: s.design,
    at: s.at,
    attachments: s.attachments,
    suggestionKey: s.key,
  );
}

final passportActionsProvider = Provider<PassportActions>(PassportActions.new);
