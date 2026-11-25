import 'package:flutter/foundation.dart';

/// Prism Wrapped's recap engine: pure functions over plain data, so it can
/// run in a background isolate and be tested without the app.
///
/// Rules: count only what was recorded; use the profile stored on each
/// record (never infer from fronting); skip cards with nothing to show;
/// never rank headmates or companions, never judge.
const wrapCardVersion = 1;

enum WrapPeriod {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  seasonal('Seasonal'),
  yearly('Yearly'),
  custom('Custom');

  const WrapPeriod(this.label);
  final String label;
}

/// Season start months (1-12), editable in settings.
const defaultSeasonStarts = {
  'spring': 3,
  'summer': 6,
  'autumn': 9,
  'winter': 12,
};

String seasonOf(DateTime d, Map<String, int> starts) {
  final order = (starts.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value)));
  var current = order.last.key;
  for (final e in order) {
    if (d.month >= e.value) current = e.key;
  }
  return current;
}

/// The [start, end) range of a period containing [anchor].
(DateTime, DateTime) periodRange(
  WrapPeriod p,
  DateTime anchor, {
  Map<String, int> seasons = defaultSeasonStarts,
  DateTime? customEnd,
}) {
  final d = DateTime(anchor.year, anchor.month, anchor.day);
  switch (p) {
    case WrapPeriod.daily:
      return (d, d.add(const Duration(days: 1)));
    case WrapPeriod.weekly:
      final start = d.subtract(Duration(days: d.weekday - 1));
      return (start, start.add(const Duration(days: 7)));
    case WrapPeriod.monthly:
      return (DateTime(d.year, d.month), DateTime(d.year, d.month + 1));
    case WrapPeriod.yearly:
      return (DateTime(d.year), DateTime(d.year + 1));
    case WrapPeriod.seasonal:
      final name = seasonOf(d, seasons);
      final m = seasons[name]!;
      final startYear = d.month >= m ? d.year : d.year - 1;
      final start = DateTime(startYear, m);
      final next = (seasons.values.toList()..sort())
          .where((x) => x > m)
          .firstOrNull;
      final end = next == null
          ? DateTime(startYear + 1, (seasons.values.toList()..sort()).first)
          : DateTime(startYear, next);
      return (start, end);
    case WrapPeriod.custom:
      final e = customEnd ?? d;
      return (d, DateTime(e.year, e.month, e.day).add(const Duration(days: 1)));
  }
}

/// One recorded thing, reduced to what recaps need.
@immutable
class WrapItem {
  const WrapItem({
    required this.id,
    required this.kind,
    required this.at,
    this.memberId,
    this.title = '',
    this.tag = '',
    this.value = 0,
    this.extra = const {},
  });
  final String id;

  /// game, creation, photo, post, celebration, stamp, passport, page,
  /// companion, interaction, outfit, habitat, play, highlight
  final String kind;
  final DateTime at;
  final String? memberId;
  final String title;

  /// Sub-type: game category, creation type, interaction kind, artist…
  final String tag;
  final num value;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'at': at.millisecondsSinceEpoch,
    'm': memberId,
    't': title,
    'g': tag,
    'v': value,
    'x': extra,
  };
  static WrapItem fromJson(Map j) => WrapItem(
    id: '${j['id']}',
    kind: '${j['kind']}',
    at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
    memberId: j['m'] as String?,
    title: '${j['t'] ?? ''}',
    tag: '${j['g'] ?? ''}',
    value: (j['v'] as num?) ?? 0,
    extra: ((j['x'] as Map?) ?? const {}).cast<String, Object?>(),
  );
}

/// Who a recap is about.
@immutable
class WrapScope {
  const WrapScope({this.type = 'system', this.ids = const []});

  /// system, member, members, subsystem, companion
  final String type;
  final List<String> ids;
  Map<String, Object?> toJson() => {'type': type, 'ids': ids};
  static WrapScope fromJson(Object? j) => j is Map
      ? WrapScope(
          type: '${j['type'] ?? 'system'}',
          ids: [for (final x in (j['ids'] as List? ?? const [])) '$x'],
        )
      : const WrapScope();
}

/// A story card. Content is frozen when the recap is saved.
@immutable
class WrapCard {
  const WrapCard({
    required this.id,
    required this.kind,
    required this.title,
    this.headline = '',
    this.subtitle = '',
    this.items = const [],
    this.chart = const [],
    this.refs = const [],
    this.note = '',
  });
  final String id;
  final String kind;
  final String title;
  final String headline;
  final String subtitle;

  /// (label, value, emoji)
  final List<(String, String, String)> items;
  final List<(String, num)> chart;

  /// Record ids to draw (companions, stamps, photos…).
  final List<String> refs;
  final String note;

  Map<String, Object?> toJson() => {
    'cv': wrapCardVersion,
    'id': id,
    'kind': kind,
    'title': title,
    'headline': headline,
    'subtitle': subtitle,
    'items': [
      for (final (a, b, c) in items) [a, b, c],
    ],
    'chart': [
      for (final (a, b) in chart) [a, b],
    ],
    'refs': refs,
    'note': note,
  };
  static WrapCard fromJson(Map j) => WrapCard(
    id: '${j['id']}',
    kind: '${j['kind']}',
    title: '${j['title'] ?? ''}',
    headline: '${j['headline'] ?? ''}',
    subtitle: '${j['subtitle'] ?? ''}',
    items: [
      for (final i in (j['items'] as List? ?? const []))
        if (i is List && i.length == 3) ('${i[0]}', '${i[1]}', '${i[2]}'),
    ],
    chart: [
      for (final c in (j['chart'] as List? ?? const []))
        if (c is List && c.length == 2) ('${c[0]}', (c[1] as num?) ?? 0),
    ],
    refs: [for (final r in (j['refs'] as List? ?? const [])) '$r'],
    note: '${j['note'] ?? ''}',
  );
}

/// Card categories the user can include or leave out.
const wrapCategories = <String, String>{
  'entertainment': 'Games & play',
  'music': 'Music',
  'creativity': 'Creativity',
  'personalization': 'Personalization',
  'memories': 'Memories & social',
  'companions': 'Companions',
  'passport': 'Passport',
  'highlights': 'Your highlights',
};

String wrapCategoryOf(String kind) => switch (kind) {
  'games' || 'gameCategories' || 'gameMoments' => 'entertainment',
  'music' || 'musicArtists' || 'musicNew' => 'music',
  'creativity' || 'colors' => 'creativity',
  'personalization' => 'personalization',
  'memories' || 'celebrations' => 'memories',
  'companions' || 'companionStory' => 'companions',
  'passport' => 'passport',
  'highlights' => 'highlights',
  _ => 'core',
};

@immutable
class WrapInput {
  const WrapInput({
    required this.from,
    required this.to,
    required this.scope,
    required this.items,
    this.subsystemMembers = const [],
    this.companionOwners = const {},
    this.categories = const {},
    this.title = '',
    this.scopeLabel = '',
    this.lookName = '',
    this.savedLooks = 0,
    this.accents = const [],
  });
  final DateTime from, to;
  final WrapScope scope;
  final List<WrapItem> items;
  final List<String> subsystemMembers;

  /// companion id → owner member ids (for headmate recaps).
  final Map<String, List<String>> companionOwners;
  final Set<String> categories;
  final String title;
  final String scopeLabel;
  final String lookName;
  final int savedLooks;
  final List<int> accents;
}

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

List<(String, int)> _top(Iterable<String> keys, [int n = 3]) {
  final c = <String, int>{};
  for (final k in keys) {
    if (k.isEmpty) continue;
    c[k] = (c[k] ?? 0) + 1;
  }
  final out = c.entries.toList()
    ..sort(
      (a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key),
    );
  return [for (final e in out.take(n)) (e.key, e.value)];
}

/// Builds the recap's cards. Pure; safe to run in an isolate.
List<WrapCard> generateWrap(WrapInput input) {
  final s = input.scope;
  bool inScope(WrapItem i) {
    if (!i.at.isBefore(input.to) || i.at.isBefore(input.from)) return false;
    switch (s.type) {
      case 'member' || 'members':
        if (i.memberId != null) return s.ids.contains(i.memberId);
        // Unattributed companion items count for the companion's owners.
        final cid = i.extra['companion'] as String?;
        return cid != null &&
            (input.companionOwners[cid] ?? const []).any(s.ids.contains);
      case 'subsystem':
        return i.memberId != null &&
            input.subsystemMembers.contains(i.memberId);
      case 'companion':
        return s.ids.contains(i.extra['companion']) || s.ids.contains(i.id);
      default:
        return true;
    }
  }

  bool want(String cat) =>
      input.categories.isEmpty || input.categories.contains(cat);
  final items = input.items.where(inScope).toList();
  List<WrapItem> of(String kind) => [
    for (final i in items)
      if (i.kind == kind) i,
  ];
  final cards = <WrapCard>[];

  cards.add(
    WrapCard(
      id: 'intro',
      kind: 'intro',
      title: input.title,
      subtitle: input.scopeLabel,
      headline: items.isEmpty
          ? 'A quiet stretch'
          : _plural(items.length, 'moment'),
      note: items.isEmpty
          ? 'Not much was recorded — and that\'s completely fine.'
          : 'Here\'s what you recorded and saved.',
    ),
  );

  final companionOnly = s.type == 'companion';

  if (!companionOnly && want('entertainment')) {
    final games = of('game');
    if (games.isNotEmpty) {
      final top = _top(games.map((g) => g.title));
      cards.add(
        WrapCard(
          id: 'games',
          kind: 'games',
          title: 'Games you played',
          headline: _plural(games.length, 'game session'),
          items: [for (final (t, n) in top) (t, _plural(n, 'time'), '🎮')],
          subtitle:
              '${_plural({for (final g in games) g.title}.length, 'different game')} in all',
        ),
      );
      final cats = _top(games.map((g) => g.tag), 7);
      if (cats.length > 1)
        cards.add(
          WrapCard(
            id: 'gameCategories',
            kind: 'gameCategories',
            title: 'What kinds of games',
            chart: [for (final (c, n) in cats) (c, n)],
          ),
        );
      final moments = [
        for (final g in games)
          if ((g.extra['memorable'] as String?)?.isNotEmpty ?? false) g,
      ];
      if (moments.isNotEmpty)
        cards.add(
          WrapCard(
            id: 'gameMoments',
            kind: 'gameMoments',
            title: 'Moments worth remembering',
            items: [
              for (final g in moments.take(4))
                (g.extra['memorable']! as String, g.title, '✨'),
            ],
          ),
        );
    }
  }

  if (!companionOnly && want('music')) {
    final plays = of('play');
    if (plays.isNotEmpty) {
      final mins = plays.fold<num>(0, (a, p) => a + p.value) / 60000;
      cards.add(
        WrapCard(
          id: 'music',
          kind: 'music',
          title: 'Your soundtrack',
          headline: _plural(plays.length, 'play'),
          subtitle: mins >= 1
              ? 'About ${mins >= 120 ? '${(mins / 60).round()} hours' : '${mins.round()} minutes'} of music played in Prism'
              : '',
          items: [
            for (final (t, n) in _top(plays.map((p) => p.title)))
              (t, _plural(n, 'play'), '🎵'),
          ],
        ),
      );
      final artists = _top(plays.map((p) => p.tag), 5);
      final albums = _top(plays.map((p) => '${p.extra['album'] ?? ''}'), 3);
      if (artists.isNotEmpty)
        cards.add(
          WrapCard(
            id: 'musicArtists',
            kind: 'musicArtists',
            title: 'Artists on repeat',
            items: [
              for (final (a, n) in artists) (a, _plural(n, 'play'), '🎤'),
              for (final (a, n) in albums) (a, _plural(n, 'play'), '💿'),
            ],
          ),
        );
      final fresh = of('track');
      if (fresh.isNotEmpty)
        cards.add(
          WrapCard(
            id: 'musicNew',
            kind: 'musicNew',
            title: 'New to your library',
            headline: _plural(fresh.length, 'song'),
            items: [for (final t in fresh.take(5)) (t.title, t.tag, '🆕')],
          ),
        );
    }
  }

  if (!companionOnly && want('creativity')) {
    final made = of('creation');
    final photos = of('photo');
    final stickers = items.fold<int>(
      0,
      (a, i) => a + ((i.extra['stickers'] as num?)?.toInt() ?? 0),
    );
    if (made.isNotEmpty || photos.isNotEmpty) {
      final byType = _top(made.map((m) => m.tag), 6);
      cards.add(
        WrapCard(
          id: 'creativity',
          kind: 'creativity',
          title: 'Things you made',
          headline: _plural(made.length + photos.length, 'creation'),
          items: [
            for (final (t, n) in byType) (t, '$n', '🎨'),
            if (photos.isNotEmpty) ('Photos saved', '${photos.length}', '📸'),
            if (stickers > 0) ('Stickers placed', '$stickers', '🌟'),
          ],
          refs: [for (final p in photos.take(4)) p.id],
        ),
      );
    }
    final colors = [
      for (final i in items) ...?((i.extra['colors'] as List?)?.cast<num>()),
    ];
    if (colors.length >= 3) {
      final top = _top(colors.map((c) => '${c.toInt()}'), 6);
      cards.add(
        WrapCard(
          id: 'colors',
          kind: 'colors',
          title: 'Colours you reached for',
          chart: [for (final (c, n) in top) (c, n)],
        ),
      );
    }
  }

  if (!companionOnly && want('personalization') && input.lookName.isNotEmpty) {
    final outfits = of('outfit');
    final covers = of('passport');
    cards.add(
      WrapCard(
        id: 'personalization',
        kind: 'personalization',
        title: 'Your look',
        headline: input.lookName,
        subtitle: input.savedLooks > 0
            ? '${_plural(input.savedLooks, 'saved look')} in your collection'
            : '',
        chart: [for (final c in input.accents) ('$c', 1)],
        items: [
          if (outfits.isNotEmpty)
            ('Companion outfits', '${outfits.length}', '👗'),
          if (covers.isNotEmpty)
            ('Passport covers designed', '${covers.length}', '📔'),
        ],
      ),
    );
  }

  if (!companionOnly && want('memories')) {
    final posts = of('post');
    final celebrations = of('celebration');
    final mems = of('memory');
    if (posts.isNotEmpty || mems.isNotEmpty) {
      cards.add(
        WrapCard(
          id: 'memories',
          kind: 'memories',
          title: 'Memories kept',
          headline: _plural(posts.length + mems.length, 'memory', 'memories'),
          items: [
            if (posts.isNotEmpty)
              ('Bulletin Board posts', '${posts.length}', '📌'),
            if (mems.isNotEmpty) ('Companion memories', '${mems.length}', '🐾'),
          ],
        ),
      );
    }
    if (celebrations.isNotEmpty)
      cards.add(
        WrapCard(
          id: 'celebrations',
          kind: 'celebrations',
          title: 'Celebrations',
          items: [
            for (final c in celebrations.take(6))
              (c.title, '${c.at.month}/${c.at.day}', '🎉'),
          ],
        ),
      );
  }

  if (want('companions')) {
    final adopted = of('companion');
    final photos = of('photo');
    final interactions = of('interaction');
    final habitats = of('habitat');
    final outfits = of('outfit');
    if (adopted.isNotEmpty ||
        photos.isNotEmpty ||
        interactions.isNotEmpty ||
        habitats.isNotEmpty) {
      final fav = _top(interactions.map((i) => i.tag), 1);
      cards.add(
        WrapCard(
          id: 'companions',
          kind: 'companions',
          title: companionOnly ? 'Time together' : 'Companion moments',
          headline: adopted.isNotEmpty
              ? '${_plural(adopted.length, 'new friend')} 🐾'
              : _plural(interactions.length + photos.length, 'moment'),
          items: [
            if (adopted.isNotEmpty)
              (
                'Adopted or hatched',
                adopted.map((a) => a.title).join(', '),
                '🥚',
              ),
            if (photos.isNotEmpty) ('Photos taken', '${photos.length}', '📸'),
            if (outfits.isNotEmpty)
              ('Outfits saved', '${outfits.length}', '👗'),
            if (habitats.isNotEmpty)
              ('Habitats decorated', '${habitats.length}', '🏡'),
            if (fav.isNotEmpty) ('Favourite thing to do', fav.first.$1, '💕'),
          ],
          refs: [for (final a in adopted) a.id],
        ),
      );
      final featured = {
        for (final i in items) ?(i.extra['companion'] as String?),
        for (final a in adopted) a.id,
      }.take(3).toList();
      for (final id in featured) {
        final story = items
            .where((i) => i.extra['companion'] == id || i.id == id)
            .toList();
        final joined = adopted.where((a) => a.id == id).firstOrNull;
        cards.add(
          WrapCard(
            id: 'companion-$id',
            kind: 'companionStory',
            title:
                story
                        .firstWhere(
                          (i) => i.extra['name'] != null,
                          orElse: () => story.first,
                        )
                        .extra['name']
                    as String? ??
                'Companion',
            headline: joined != null
                ? 'Joined the family'
                : _plural(story.length, 'moment'),
            refs: [id],
            subtitle: [
              if (story.any((i) => i.kind == 'photo')) 'starred in photos',
              if (story.any((i) => i.kind == 'outfit')) 'tried new outfits',
              if (story.any((i) => i.kind == 'interaction'))
                'spent time with you',
            ].join(' · '),
          ),
        );
      }
    }
  }

  if (!companionOnly && want('passport')) {
    final stamps = of('stamp');
    final passports = of('passport');
    final pages = of('page');
    if (stamps.isNotEmpty || passports.isNotEmpty) {
      cards.add(
        WrapCard(
          id: 'passport',
          kind: 'passport',
          title: 'Passport',
          headline: _plural(stamps.length, 'stamp'),
          items: [
            if (passports.isNotEmpty)
              ('New passports', '${passports.length}', '📔'),
            if (pages.isNotEmpty) ('Pages decorated', '${pages.length}', '📄'),
          ],
          refs: [for (final s in stamps.reversed.take(6)) s.id],
        ),
      );
    }
  }

  if (want('highlights')) {
    final picks = of('highlight');
    if (picks.isNotEmpty)
      cards.add(
        WrapCard(
          id: 'highlights',
          kind: 'highlights',
          title: 'Highlights you chose',
          items: [
            for (final p in picks.take(6))
              (p.title, '${p.at.month}/${p.at.day}', '⭐'),
          ],
        ),
      );
  }

  cards.add(
    WrapCard(
      id: 'closing',
      kind: 'closing',
      title: 'Thanks for being here',
      note: items.length < 3
          ? 'Every season has quiet stretches. Whatever you recorded — or didn\'t — this is yours.'
          : 'Here\'s to more moments worth keeping.',
    ),
  );
  return cards;
}

/// [generateWrap] for `compute` (takes and returns JSON-friendly data).
List<Map<String, Object?>> generateWrapJson(Map<String, Object?> raw) {
  final input = WrapInput(
    from: DateTime.fromMillisecondsSinceEpoch(raw['from']! as int),
    to: DateTime.fromMillisecondsSinceEpoch(raw['to']! as int),
    scope: WrapScope.fromJson(raw['scope']),
    items: [for (final i in raw['items']! as List) WrapItem.fromJson(i as Map)],
    subsystemMembers: [for (final x in raw['sub'] as List? ?? const []) '$x'],
    companionOwners: {
      for (final e in ((raw['owners'] as Map?) ?? const {}).entries)
        '${e.key}': [for (final x in e.value as List) '$x'],
    },
    categories: {for (final x in raw['cats'] as List? ?? const []) '$x'},
    title: '${raw['title'] ?? ''}',
    scopeLabel: '${raw['scopeLabel'] ?? ''}',
    lookName: '${raw['look'] ?? ''}',
    savedLooks: (raw['savedLooks'] as num?)?.toInt() ?? 0,
    accents: [
      for (final x in raw['accents'] as List? ?? const []) (x as num).toInt(),
    ],
  );
  return [for (final c in generateWrap(input)) c.toJson()];
}
