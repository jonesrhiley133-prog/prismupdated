import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/features/appearance/services/appearance_store.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider, subsystemNamesProvider;
import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/social/models/social.dart'
    show SocialKind;
import 'package:prism_plurality/features/subsystems/hub/subsystem_data.dart';
import 'package:prism_plurality/features/wrapped/wrapped_engine.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Visual styles for recaps. "prism" follows the user's own theme.
const wrapStyles = <String, String>{
  'prism': 'Current Prism theme',
  'minimal': 'Minimal',
  'celestial': 'Celestial',
  'cozy': 'Cozy',
  'scrapbook': 'Scrapbook',
  'retro': 'Retro',
  'pastel': 'Pastel',
  'dark': 'Dark',
  'editorial': 'Editorial',
  'polaroid': 'Polaroid',
  'magazine': 'Magazine',
};

@immutable
class WrapStyle {
  const WrapStyle({
    this.style = 'prism',
    this.accent,
    this.font = 'sans',
    this.animation = 'slide',
    this.speed = 1,
    this.effects = true,
    this.music = 'none',
    this.aspect = 'story',
    this.hideNames = false,
    this.hideNumbers = false,
    this.order = const [],
    this.removed = const {},
  });
  final String style;
  final int? accent;
  final String font;

  /// slide, fade, zoom, none
  final String animation;
  final double speed;
  final bool effects;

  /// none, waves, stream, wind, rain
  final String music;

  /// story (9:16), portrait (4:5), square (1:1)
  final String aspect;
  final bool hideNames, hideNumbers;
  final List<String> order;
  final Set<String> removed;

  double get ratio => switch (aspect) {
    'square' => 1,
    'portrait' => 4 / 5,
    _ => 9 / 16,
  };

  Map<String, Object?> toJson() => {
    'style': style,
    'accent': accent,
    'font': font,
    'animation': animation,
    'speed': speed,
    'effects': effects,
    'music': music,
    'aspect': aspect,
    'hideNames': hideNames,
    'hideNumbers': hideNumbers,
    'order': order,
    'removed': removed.toList(),
  };
  static WrapStyle fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    return WrapStyle(
      style: wrapStyles.containsKey(j['style'])
          ? j['style'] as String
          : 'prism',
      accent: (j['accent'] as num?)?.toInt(),
      font: '${j['font'] ?? 'sans'}',
      animation: '${j['animation'] ?? 'slide'}',
      speed: ((j['speed'] as num?)?.toDouble() ?? 1).clamp(0.5, 2),
      effects: j['effects'] != false,
      music: '${j['music'] ?? 'none'}',
      aspect: '${j['aspect'] ?? 'story'}',
      hideNames: j['hideNames'] == true,
      hideNumbers: j['hideNumbers'] == true,
      order: [for (final x in (j['order'] as List? ?? const [])) '$x'],
      removed: {for (final x in (j['removed'] as List? ?? const [])) '$x'},
    );
  }

  WrapStyle copyWith({
    String? style,
    int? accent,
    bool clearAccent = false,
    String? font,
    String? animation,
    double? speed,
    bool? effects,
    String? music,
    String? aspect,
    bool? hideNames,
    bool? hideNumbers,
    List<String>? order,
    Set<String>? removed,
  }) => WrapStyle(
    style: style ?? this.style,
    accent: clearAccent ? null : (accent ?? this.accent),
    font: font ?? this.font,
    animation: animation ?? this.animation,
    speed: speed ?? this.speed,
    effects: effects ?? this.effects,
    music: music ?? this.music,
    aspect: aspect ?? this.aspect,
    hideNames: hideNames ?? this.hideNames,
    hideNumbers: hideNumbers ?? this.hideNumbers,
    order: order ?? this.order,
    removed: removed ?? this.removed,
  );

  /// Cards in the chosen order, minus removed ones.
  List<WrapCard> arrange(List<WrapCard> cards) {
    final byId = {for (final c in cards) c.id: c};
    final ordered = [
      for (final id in order) ?byId[id],
      for (final c in cards)
        if (!order.contains(c.id)) c,
    ];
    return [
      for (final c in ordered)
        if (!removed.contains(c.id)) c,
    ];
  }
}

/// A saved recap. Its cards are frozen; they only change if the user
/// explicitly regenerates.
class WrapSnapshot {
  WrapSnapshot(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get title => r.title.isEmpty ? 'Recap' : r.title;
  WrapPeriod get period =>
      WrapPeriod.values
          .where((p) => p.name == r.fields['period'])
          .firstOrNull ??
      WrapPeriod.custom;
  DateTime get from => DateTime.tryParse('${r.fields['from']}') ?? r.createdAt;
  DateTime get to => DateTime.tryParse('${r.fields['to']}') ?? r.createdAt;
  WrapScope get scope => WrapScope.fromJson(r.fields['scope']);
  WrapStyle get style => WrapStyle.fromJson(r.fields['style']);
  List<WrapCard> get cards => [
    for (final c in (r.fields['cards'] as List? ?? const []))
      if (c is Map) WrapCard.fromJson(c),
  ];
  Set<String> get categories => {
    for (final x in (r.fields['categories'] as List? ?? const [])) '$x',
  };
  List<String> get highlights => [
    for (final x in (r.fields['highlights'] as List? ?? const [])) '$x',
  ];
  bool get favorite => r.flag('favorite');
  String get collection => '${r.fields['collection'] ?? ''}';
  Map<String, String> get attribution => {
    for (final e in ((r.fields['attribution'] as Map?) ?? const {}).entries)
      '${e.key}': '${e.value ?? ''}',
  };
}

class WrapSettings {
  const WrapSettings({this.record, this.seasons = defaultSeasonStarts});
  final TrackerRecord? record;
  final Map<String, int> seasons;
  static WrapSettings of(TrackerRecord? r) {
    final raw = r?.fields['seasons'];
    return WrapSettings(
      record: r,
      seasons: raw is Map
          ? {
              for (final e in raw.entries)
                '${e.key}': ((e.value as num?)?.toInt() ?? 1).clamp(1, 12),
            }
          : defaultSeasonStarts,
    );
  }
}

final wrapSnapshotsProvider = Provider<List<WrapSnapshot>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.wrapSnapshot)).value ??
            const <TrackerRecord>[])
      WrapSnapshot(r),
  ]..sort((a, b) => b.r.createdAt.compareTo(a.r.createdAt)),
);
final wrapSettingsProvider = Provider<WrapSettings>((ref) {
  final rows =
      ref.watch(trackerKindProvider(TrackerKind.wrapSettings)).value ??
      const <TrackerRecord>[];
  return WrapSettings.of(rows.firstOrNull);
});

/// Everything recorded in Prism, reduced to recap items. Journal entries
/// appear only when the user explicitly picks them as highlights.
final wrapItemsProvider = Provider<List<WrapItem>>((ref) {
  final out = <WrapItem>[];
  List<TrackerRecord> kind(String k) =>
      ref.watch(trackerKindProvider(k)).value ?? const <TrackerRecord>[];
  for (final r in kind(TrackerKind.gameResult)) {
    final def = gameById(r.title);
    out.add(
      WrapItem(
        id: r.id,
        kind: 'game',
        at: r.occurredAt ?? r.createdAt,
        memberId: r.memberId,
        title: def?.name.$1 ?? r.title,
        tag: def?.category.label.$1 ?? 'Games',
        extra: {'memorable': r.fields['memorable']},
      ),
    );
  }
  for (final (k, label) in [
    (TrackerKind.scrapPage, 'Scrapbook pages'),
    (TrackerKind.cozyDoodle, 'Doodles'),
    (TrackerKind.gameProject, 'Stories & projects'),
  ]) {
    for (final r in kind(k)) {
      out.add(
        WrapItem(
          id: r.id,
          kind: 'creation',
          at: r.createdAt,
          memberId: r.memberId,
          title: r.title,
          tag: label,
        ),
      );
    }
  }
  final companions = ref.watch(companionsProvider);
  final names = {for (final c in companions) c.id: c.name};
  for (final c in companions) {
    out.add(
      WrapItem(
        id: c.id,
        kind: 'companion',
        at: c.adoptedAt,
        title: c.name,
        extra: {
          'companion': c.id,
          'name': c.name,
          'colors': [c.look.primaryOf(c.species).toARGB32()],
        },
      ),
    );
  }
  for (final m in ref.watch(companionMemoriesProvider)) {
    final cid = m.companionIds.firstOrNull;
    if (m.kind == 'photo') {
      out.add(
        WrapItem(
          id: m.id,
          kind: 'photo',
          at: m.at,
          memberId: m.r.memberId,
          title: m.title,
          extra: {
            'companion': cid,
            'name': names[cid],
            'stickers': m.scene?.stickers.length ?? 0,
          },
        ),
      );
    } else if (m.kind == 'note' || m.kind == 'milestone') {
      out.add(
        WrapItem(
          id: m.id,
          kind: 'memory',
          at: m.at,
          memberId: m.r.memberId,
          title: m.title,
          extra: {'companion': cid, 'name': names[cid]},
        ),
      );
    }
  }
  for (final i in ref.watch(companionInteractionsProvider)) {
    out.add(
      WrapItem(
        id: i.r.id,
        kind: 'interaction',
        at: i.at,
        memberId: i.by,
        tag: companionInteractions[i.kind]?.$1 ?? i.kind,
        extra: {'companion': i.companionId, 'name': names[i.companionId]},
      ),
    );
  }
  for (final r in kind(TrackerKind.companionOutfit)) {
    out.add(
      WrapItem(
        id: r.id,
        kind: 'outfit',
        at: r.createdAt,
        title: r.title,
        extra: {
          'companion': r.parentId,
          'name': names[r.parentId],
          'colors': [
            ?((r.fields['look'] as Map?)?['primary'] as num?)?.toInt(),
          ],
        },
      ),
    );
  }
  for (final h in ref.watch(habitatsProvider)) {
    if (h.items.isNotEmpty)
      out.add(
        WrapItem(id: h.id, kind: 'habitat', at: h.r.modifiedAt, title: h.name),
      );
  }
  final passports = ref.watch(passportsProvider);
  String? soleOwner(Passport? p) =>
      p != null && p.ownerType == OwnerType.member && p.owners.length == 1
      ? p.owners.first
      : null;
  for (final p in passports) {
    out.add(
      WrapItem(
        id: p.id,
        kind: 'passport',
        at: p.r.createdAt,
        memberId: soleOwner(p),
        title: p.name,
        extra: {
          'colors': [p.cover.primary],
        },
      ),
    );
  }
  final byId = {for (final p in passports) p.id: p};
  for (final s in ref.watch(allStampsProvider)) {
    out.add(
      WrapItem(
        id: s.id,
        kind: 'stamp',
        at: s.at,
        memberId: soleOwner(byId[s.passportId]),
        title: s.title,
        tag: s.category,
        extra: {
          'colors': [s.design.color],
        },
      ),
    );
  }
  for (final r in kind(TrackerKind.passportPage)) {
    out.add(
      WrapItem(
        id: r.id,
        kind: 'page',
        at: r.createdAt,
        memberId: soleOwner(byId[r.parentId]),
        title: r.title,
        tag: 'Passport pages',
      ),
    );
  }
  for (final r
      in ref.watch(trackerKindProvider(SocialKind.post)).value ??
          const <TrackerRecord>[]) {
    if (r.fields['status'] == 'draft' || r.fields['status'] == 'scheduled')
      continue;
    out.add(
      WrapItem(
        id: r.id,
        kind: 'post',
        at: r.occurredAt ?? r.createdAt,
        memberId: r.memberId,
        title: r.title,
      ),
    );
  }
  final celebrate = RegExp(
    r'birthday|anniversar|party|celebrat|holiday|festival|concert|🎉|🎂',
    caseSensitive: false,
  );
  for (final e
      in ref.watch(calendarEventsProvider).value ?? const <CalendarEvent>[]) {
    if (celebrate.hasMatch('${e.category ?? ''} ${e.title}'))
      out.add(
        WrapItem(
          id: e.id,
          kind: 'celebration',
          at: e.startAt,
          memberId: e.memberIds.length == 1 ? e.memberIds.first : null,
          title: e.title,
        ),
      );
  }
  final lib = ref.watch(musicLibraryProvider).value;
  if (lib != null) {
    for (final (id, at) in lib.plays) {
      final t = lib.track(id);
      if (t == null) continue;
      out.add(
        WrapItem(
          id: '$id@${at.millisecondsSinceEpoch}',
          kind: 'play',
          at: at,
          title: t.title,
          tag: t.artist,
          value: t.durationMs,
          extra: {'album': t.album},
        ),
      );
    }
    for (final t in lib.tracks) {
      out.add(
        WrapItem(
          id: 't:${t.id}',
          kind: 'track',
          at: t.addedAt,
          title: t.title,
          tag: t.artist,
        ),
      );
    }
  }
  return out;
});

String wrapTitle(
  WrapPeriod p,
  DateTime from,
  DateTime to, {
  Map<String, int> seasons = defaultSeasonStarts,
}) => switch (p) {
  WrapPeriod.daily => DateFormat.yMMMMEEEEd().format(from),
  WrapPeriod.weekly => 'Week of ${DateFormat.MMMd().format(from)}',
  WrapPeriod.monthly => DateFormat.yMMMM().format(from),
  WrapPeriod.seasonal =>
    '${seasonOf(from, seasons)[0].toUpperCase()}${seasonOf(from, seasons).substring(1)} ${from.year}',
  WrapPeriod.yearly => '${from.year} Wrapped',
  WrapPeriod.custom =>
    '${DateFormat.yMMMd().format(from)} – ${DateFormat.yMMMd().format(to.subtract(const Duration(days: 1)))}',
};

class WrapActions {
  WrapActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  /// Builds a recap from the records on this device (works offline).
  Future<List<WrapCard>> generate({
    required DateTime from,
    required DateTime to,
    required WrapScope scope,
    Set<String> categories = const {},
    List<String> highlights = const [],
    String title = '',
    Map<String, String> attribution = const {},
  }) async {
    // Corrections from the studio: item id → member id, or '' to leave it out.
    final items = [
      for (final i in ref.read(wrapItemsProvider))
        if (attribution[i.id] == '')
          ...[]
        else if (attribution[i.id] != null)
          WrapItem(
            id: i.id,
            kind: i.kind,
            at: i.at,
            memberId: attribution[i.id],
            title: i.title,
            tag: i.tag,
            value: i.value,
            extra: i.extra,
          )
        else
          i,
    ];
    if (highlights.isNotEmpty) {
      final journal =
          ref.read(trackerKindProvider(TrackerKind.journalEntry)).value ??
          const <TrackerRecord>[];
      for (final r in journal.where((r) => highlights.contains(r.id))) {
        items.add(
          WrapItem(
            id: r.id,
            kind: 'highlight',
            at: r.occurredAt ?? r.createdAt,
            memberId: r.memberId,
            title: r.title.isEmpty ? 'A journal moment' : r.title,
          ),
        );
      }
    }
    final memberships = ref.read(subMembershipsProvider);
    final names = ref.read(memberNamesProvider);
    final subs = ref.read(subsystemNamesProvider);
    final companions = ref.read(companionsProvider);
    final scopeLabel = switch (scope.type) {
      'member' ||
      'members' => scope.ids.map((id) => names[id] ?? '?').join(' & '),
      'subsystem' => scope.ids.map((id) => subs[id] ?? 'Subsystem').join(', '),
      'companion' =>
        scope.ids
            .map(
              (id) =>
                  companions.where((c) => c.id == id).firstOrNull?.name ??
                  'Companion',
            )
            .join(' & '),
      _ => 'The whole system',
    };
    final look = ref.read(appearanceProvider).value;
    final active = look?.all.where((l) => l.id == look.activeId).firstOrNull;
    final raw = <String, Object?>{
      'from': from.millisecondsSinceEpoch,
      'to': to.millisecondsSinceEpoch,
      'scope': scope.toJson(),
      'items': [for (final i in items) i.toJson()],
      'sub': [
        for (final m in memberships)
          if (scope.ids.contains(m.subsystemId)) m.memberId,
      ],
      'owners': {
        for (final c in companions)
          c.id: c.ownerType == OwnerType.subsystem
              ? [
                  for (final m in memberships)
                    if (c.owners.contains(m.subsystemId)) m.memberId,
                ]
              : c.owners,
      },
      'cats': categories.toList(),
      'title': title,
      'scopeLabel': scopeLabel,
      'look': active?.name ?? 'Prism',
      'savedLooks': look?.looks.length ?? 0,
      'accents': [?look?.customSecondary, ?look?.customTertiary],
    };
    final json = kIsWeb
        ? generateWrapJson(raw)
        : await compute(generateWrapJson, raw);
    return [for (final c in json) WrapCard.fromJson(c)];
  }

  Future<TrackerRecord> save({
    required String title,
    required WrapPeriod period,
    required DateTime from,
    required DateTime to,
    required WrapScope scope,
    required WrapStyle style,
    required List<WrapCard> cards,
    Set<String> categories = const {},
    List<String> highlights = const [],
  }) => _t.create(
    kind: TrackerKind.wrapSnapshot,
    title: title,
    fields: {
      'v': 1,
      'period': period.name,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'scope': scope.toJson(),
      'style': style.toJson(),
      'cards': [for (final c in cards) c.toJson()],
      'categories': categories.toList(),
      'highlights': highlights,
    },
  );

  Future<void> update(
    WrapSnapshot s,
    Map<String, Object?> changes, {
    String? title,
  }) => _t.save(
    s.r.copyWith(title: title ?? s.r.title).withFields({
      ...s.r.fields,
      ...changes,
    }),
  );

  Future<TrackerRecord> duplicate(WrapSnapshot s) => _t.create(
    kind: TrackerKind.wrapSnapshot,
    title: '${s.title} (copy)',
    fields: {...s.r.fields, 'favorite': false},
  );

  Future<void> delete(WrapSnapshot s) => _t.delete(s.id, children: false);

  Future<void> saveSeasons(Map<String, int> seasons) async {
    final s = ref.read(wrapSettingsProvider);
    if (s.record == null) {
      await _t.create(
        kind: TrackerKind.wrapSettings,
        fields: {'seasons': seasons},
      );
    } else {
      await _t.save(
        s.record!.withFields({...s.record!.fields, 'seasons': seasons}),
      );
    }
  }
}

final wrapActionsProvider = Provider<WrapActions>(WrapActions.new);
