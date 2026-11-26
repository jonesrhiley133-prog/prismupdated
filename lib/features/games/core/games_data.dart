import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

// ---------------------------------------------------------------------------
// Records
// ---------------------------------------------------------------------------

class GameResult {
  GameResult(this.r);
  final TrackerRecord r;
  String get gameId => r.title;
  String? get memberId => r.memberId;
  int? get score => r.amount;
  int? get max => (r.fields['max'] as num?)?.toInt();
  String get summary => '${r.fields['summary'] ?? ''}';
  String? get memorable => r.fields['memorable'] as String?;
  String? get challengeId => r.fields['challenge'] as String?;
  String? get nightId => r.fields['night'] as String?;
  DateTime get when => r.occurredAt ?? r.createdAt;
  double? get ratio =>
      score == null || max == null || max == 0 ? null : score! / max!;
}

class GameChallenge {
  GameChallenge(this.r);
  final TrackerRecord r;
  String get gameId => r.title;
  String? get from => r.memberId;
  int get seed => (r.fields['seed'] as num?)?.toInt() ?? 0;
  List<String> get to => [
    for (final v in (r.fields['to'] as List?) ?? const []) '$v',
  ];
  String get message => r.body ?? '';
  Map<String, dynamic> get custom =>
      (r.fields['custom'] as Map?)?.cast<String, dynamic>() ?? const {};
  DateTime get when => r.createdAt;
}

/// Per-alter recreation profile: favourites and whether stats are hidden.
class GameProfile {
  const GameProfile({
    this.record,
    this.favorites = const [],
    this.hideStats = false,
    this.clues = const [],
  });
  final TrackerRecord? record;
  final List<String> favorites;
  final bool hideStats;

  /// Clues an alter chose to share for Guess the Alter.
  final List<String> clues;

  Map<String, Object?> get fields => {
    'favorites': favorites,
    'hideStats': hideStats,
    'clues': clues,
  };

  static GameProfile of(TrackerRecord? r) => GameProfile(
    record: r,
    favorites: [
      for (final v in (r?.fields['favorites'] as List?) ?? const []) '$v',
    ],
    hideStats: r?.fields['hideStats'] == true,
    clues: [for (final v in (r?.fields['clues'] as List?) ?? const []) '$v'],
  );
}

final gameResultsProvider = Provider<List<GameResult>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.gameResult)).value ??
            const <TrackerRecord>[])
      GameResult(r),
  ],
);

final gameSavesProvider = Provider<List<TrackerRecord>>(
  (ref) =>
      ref.watch(trackerKindProvider(TrackerKind.gameSave)).value ?? const [],
);

final gameChallengesProvider = Provider<List<GameChallenge>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.gameChallenge)).value ??
            const <TrackerRecord>[])
      GameChallenge(r),
  ],
);

/// Profiles by member id ('' = the shared, no-alter profile).
final gameProfilesProvider = Provider<Map<String, GameProfile>>((ref) {
  final list =
      ref.watch(trackerKindProvider(TrackerKind.gameProfile)).value ??
      const <TrackerRecord>[];
  return {for (final r in list.reversed) r.memberId ?? '': GameProfile.of(r)};
});

/// Who's playing by default: whoever fronts (never required).
final gamePlayerDefaultProvider = Provider<String?>(
  (ref) => ref.watch(currentFronterProvider).value?.id,
);

final gameMembersProvider = Provider<List<Member>>(
  (ref) => ref.watch(userVisibleMembersProvider).value ?? const [],
);

final gameNamesProvider = Provider<Map<String, String>>((ref) {
  final prefer = ref.watch(memberNamePreferDisplayProvider);
  return {
    for (final m in ref.watch(gameMembersProvider))
      m.id: m.effectiveName(preferDisplayName: prefer),
  };
});

class GamesActions {
  GamesActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<void> recordResult({
    required String gameId,
    String? memberId,
    int? score,
    int? max,
    String summary = '',
    String? memorable,
    String? challengeId,
    String? nightId,
    Map<String, Object?> details = const {},
  }) => _t.create(
    kind: TrackerKind.gameResult,
    title: gameId,
    memberId: memberId,
    amount: score,
    occurredAt: DateTime.now(),
    fields: {
      'max': max,
      'summary': summary,
      'memorable': memorable,
      'challenge': challengeId,
      'night': nightId,
      'details': details,
    },
  );

  TrackerRecord? saveFor(String gameId, String? memberId) => ref
      .read(gameSavesProvider)
      .where((r) => r.title == gameId && r.memberId == memberId)
      .firstOrNull;

  Future<void> writeSave(
    String gameId,
    String? memberId,
    Map<String, Object?> state, {
    int? seed,
  }) async {
    final existing = saveFor(gameId, memberId);
    final fields = {'state': state, 'seed': seed};
    if (existing == null) {
      await _t.create(
        kind: TrackerKind.gameSave,
        title: gameId,
        memberId: memberId,
        fields: fields,
        occurredAt: DateTime.now(),
      );
    } else {
      await _t.save(
        existing.copyWith(occurredAt: DateTime.now()).withFields(fields),
      );
    }
  }

  Future<void> clearSave(String gameId, String? memberId) async {
    final existing = saveFor(gameId, memberId);
    if (existing != null) await _t.delete(existing.id);
  }

  Future<void> toggleFavorite(String gameId, String? memberId) async {
    final key = memberId ?? '';
    final p = ref.read(gameProfilesProvider)[key] ?? const GameProfile();
    final favs = [...p.favorites];
    favs.contains(gameId) ? favs.remove(gameId) : favs.add(gameId);
    await _writeProfile(memberId, p, {...p.fields, 'favorites': favs});
  }

  Future<void> setHideStats(String memberId, bool hide) async {
    final p = ref.read(gameProfilesProvider)[memberId] ?? const GameProfile();
    await _writeProfile(memberId, p, {...p.fields, 'hideStats': hide});
  }

  Future<void> setClues(String memberId, List<String> clues) async {
    final p = ref.read(gameProfilesProvider)[memberId] ?? const GameProfile();
    await _writeProfile(memberId, p, {...p.fields, 'clues': clues});
  }

  Future<void> _writeProfile(
    String? memberId,
    GameProfile p,
    Map<String, Object?> fields,
  ) async {
    if (p.record == null) {
      await _t.create(
        kind: TrackerKind.gameProfile,
        memberId: memberId,
        fields: fields,
      );
    } else {
      await _t.save(p.record!.withFields(fields));
    }
  }

  Future<TrackerRecord> createChallenge({
    required String gameId,
    required String? from,
    required List<String> to,
    required int seed,
    String message = '',
    Map<String, Object?>? custom,
  }) => _t.create(
    kind: TrackerKind.gameChallenge,
    title: gameId,
    memberId: from,
    body: message,
    fields: {'seed': seed, 'to': to, 'custom': custom},
  );

  Future<void> delete(TrackerRecord r) => _t.delete(r.id);
}

final gamesActionsProvider = Provider<GamesActions>(GamesActions.new);

// ---------------------------------------------------------------------------
// Choosing alters (independent of fronting)
// ---------------------------------------------------------------------------

/// Small avatar for an alter id.
class AlterDot extends ConsumerWidget {
  const AlterDot(this.memberId, {super.key, this.size = 28});
  final String? memberId;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref
        .watch(gameMembersProvider)
        .where((x) => x.id == memberId)
        .firstOrNull;
    if (m == null) {
      return PrismCircleAvatar(
        radius: size / 2,
        child: Icon(PhosphorIcons.users(), size: size * 0.55),
      );
    }
    return MemberAvatar(
      avatarImageData: m.avatarImageData,
      memberName: m.name,
      emoji: m.emoji,
      customColorEnabled: m.customColorEnabled,
      customColorHex: m.customColorHex,
      size: size,
    );
  }
}

/// Opens a picker for one or more alters. Fronting doesn't limit who can be
/// chosen; whoever fronts is just suggested first.
Future<List<String>?> pickAlters(
  BuildContext context,
  WidgetRef ref, {
  List<String> selected = const [],
  int max = 8,
  String? title,
}) {
  final members = ref.read(gameMembersProvider);
  final names = ref.read(gameNamesProvider);
  final fronter = ref.read(gamePlayerDefaultProvider);
  final ordered = [...members]
    ..sort(
      (a, b) => a.id == fronter
          ? -1
          : b.id == fronter
          ? 1
          : 0,
    );
  return PrismSheet.show<List<String>>(
    context: context,
    title: title ?? tr(context, 'Choose alters', 'Elegir alters'),
    maxHeightFactor: 0.85,
    builder: (ctx) {
      final picked = [...selected];
      return StatefulBuilder(
        builder: (ctx, set) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  for (final m in ordered.take(400))
                    PrismListRow(
                      dense: true,
                      leading: AlterDot(m.id, size: 32),
                      title: Text(names[m.id] ?? m.name),
                      subtitle: m.id == fronter
                          ? Text(tr(ctx, 'Fronting now', 'Al frente ahora'))
                          : null,
                      selected: picked.contains(m.id),
                      trailing: picked.contains(m.id)
                          ? Icon(
                              PhosphorIcons.checkCircle(
                                PhosphorIconsStyle.fill,
                              ),
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      onTap: () => set(() {
                        if (picked.contains(m.id)) {
                          picked.remove(m.id);
                        } else if (max == 1) {
                          picked
                            ..clear()
                            ..add(m.id);
                        } else if (picked.length < max) {
                          picked.add(m.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: PrismButton(
                tone: PrismButtonTone.filled,
                expanded: true,
                label: picked.isEmpty
                    ? tr(ctx, 'Continue without choosing', 'Seguir sin elegir')
                    : tr(
                        ctx,
                        'Done (${picked.length})',
                        'Listo (${picked.length})',
                      ),
                onPressed: () => Navigator.of(ctx).pop(picked),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A row of chosen alters with a change button.
class AlterChips extends ConsumerWidget {
  const AlterChips({
    super.key,
    required this.ids,
    required this.onTap,
    this.emptyLabel,
  });
  final List<String> ids;
  final VoidCallback onTap;
  final String? emptyLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(gameNamesProvider);
    return PrismSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (ids.isEmpty)
            Expanded(
              child: Text(
                emptyLabel ??
                    tr(
                      context,
                      'Anyone — tap to choose alters',
                      'Cualquiera: toca para elegir alters',
                    ),
              ),
            )
          else
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final id in ids)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AlterDot(id, size: 24),
                        const SizedBox(width: 5),
                        Text(
                          names[id] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Icon(PhosphorIcons.pencilSimple(), size: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom games and game nights
// ---------------------------------------------------------------------------

/// A game an alter made: `fields.base` is the template game id and
/// `fields.content` the custom content (see buildCustom).
class CustomGame {
  CustomGame(this.r);
  final TrackerRecord r;
  String get title => r.title;
  String get base => '${r.fields['base'] ?? 'trivia_general'}';
  String get type => '${content['type'] ?? ''}';
  Map<String, Object?> get content =>
      (r.fields['content'] as Map?)?.cast<String, Object?>() ?? const {};
  String? get creator => r.memberId;
}

final customGamesProvider = Provider<List<CustomGame>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.gameCustom)).value ??
            const <TrackerRecord>[])
      CustomGame(r),
  ],
);

/// A planned or finished game night.
class GameNight {
  GameNight(this.r);
  final TrackerRecord r;
  String get title => r.title;
  DateTime? get when => r.occurredAt;
  List<String> get players => [
    for (final v in (r.fields['players'] as List?) ?? const []) '$v',
  ];
  List<String> get games => [
    for (final v in (r.fields['games'] as List?) ?? const []) '$v',
  ];

  /// Index of the next game to play.
  int get progress => (r.fields['progress'] as num?)?.toInt() ?? 0;
  bool get coop => r.fields['coop'] == true;
  String get status =>
      '${r.fields['status'] ?? 'planned'}'; // planned | live | paused | done
  String? get calendarEventId => r.fields['calendar'] as String?;
  String get notes => r.body ?? '';
}

final gameNightsProvider = Provider<List<GameNight>>((ref) {
  final list = [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.gameNight)).value ??
            const <TrackerRecord>[])
      GameNight(r),
  ];
  list.sort(
    (a, b) => (b.when ?? b.r.createdAt).compareTo(a.when ?? a.r.createdAt),
  );
  return list;
});
