import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/views/games_hub_screen.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A gentle achievement: no streaks, no deadlines, never lost once earned.
class FriendlyAchievement {
  const FriendlyAchievement(
    this.id,
    this.emoji,
    this.name,
    this.desc,
    this.check,
  );
  final String id;
  final String emoji;
  final (String, String) name;
  final (String, String) desc;
  final bool Function(GameStats s) check;
}

/// Everything achievements and profiles need about one alter's play.
class GameStats {
  GameStats(this.results, {this.customMade = 0});
  final List<GameResult> results;
  final int customMade;

  late final Set<String> distinct = {for (final r in results) r.gameId};
  late final Map<GameCategory, int> byCategory = () {
    final m = <GameCategory, int>{};
    for (final r in results) {
      final g = gameById(r.gameId);
      if (g != null) m[g.category] = (m[g.category] ?? 0) + 1;
    }
    return m;
  }();
  late final int days = {
    for (final r in results) DateTime(r.when.year, r.when.month, r.when.day),
  }.length;
  int playedOf(Iterable<String> ids) =>
      results.where((r) => ids.contains(r.gameId)).length;
  GameCategory? get favouriteCategory => byCategory.isEmpty
      ? null
      : (byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
}

final friendlyAchievements = <FriendlyAchievement>[
  FriendlyAchievement(
    'first',
    '🎲',
    ('First Game', 'Primer juego'),
    ('Played any game.', 'Jugaste cualquier juego.'),
    (s) => s.results.isNotEmpty,
  ),
  FriendlyAchievement(
    'trivia',
    '🧠',
    ('Curious Mind', 'Mente curiosa'),
    ('Played 5 trivia games.', 'Jugaste 5 trivias.'),
    (s) => (s.byCategory[GameCategory.trivia] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'word',
    '🔤',
    ('Wordsmith', 'Artesano de palabras'),
    ('Played 5 word games.', 'Jugaste 5 juegos de palabras.'),
    (s) => (s.byCategory[GameCategory.word] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'logic',
    '🧩',
    ('Puzzle Pal', 'Amigo de los puzles'),
    ('Played 5 logic puzzles.', 'Jugaste 5 puzles de lógica.'),
    (s) => (s.byCategory[GameCategory.logic] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'cozy',
    '🌿',
    ('Cozy Creator', 'Creador acogedor'),
    ('Enjoyed 5 relaxing activities.', 'Disfrutaste 5 actividades relajantes.'),
    (s) => (s.byCategory[GameCategory.cozy] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'memory',
    '🃏',
    ('Memory Keeper', 'Guardián de recuerdos'),
    ('Played 5 memory games.', 'Jugaste 5 juegos de memoria.'),
    (s) => (s.byCategory[GameCategory.memory] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'social',
    '🎉',
    ('Party Spark', 'Chispa de la fiesta'),
    ('Played 5 social games.', 'Jugaste 5 juegos sociales.'),
    (s) => (s.byCategory[GameCategory.social] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'creative',
    '🎨',
    ('Creative Spirit', 'Espíritu creativo'),
    (
      'Played 5 creative or learning games.',
      'Jugaste 5 juegos creativos o educativos.',
    ),
    (s) => (s.byCategory[GameCategory.creative] ?? 0) >= 5,
  ),
  FriendlyAchievement(
    'explorer',
    '🧭',
    ('Explorer', 'Explorador'),
    ('Tried 10 different games.', 'Probaste 10 juegos distintos.'),
    (s) => s.distinct.length >= 10,
  ),
  FriendlyAchievement(
    'rainbow',
    '🌈',
    ('Little of Everything', 'Un poco de todo'),
    (
      'Played a game from every category.',
      'Jugaste un juego de cada categoría.',
    ),
    (s) => s.byCategory.length >= GameCategory.values.length,
  ),
  FriendlyAchievement(
    'collector',
    '📚',
    ('Collector', 'Coleccionista'),
    ('Tried 30 different games.', 'Probaste 30 juegos distintos.'),
    (s) => s.distinct.length >= 30,
  ),
  FriendlyAchievement(
    'challenge',
    '📨',
    ('Challenge Accepted', 'Reto aceptado'),
    (
      'Played a challenge from another alter.',
      'Jugaste un reto de otro alter.',
    ),
    (s) => s.results.any((r) => r.challengeId != null),
  ),
  FriendlyAchievement(
    'night',
    '🌙',
    ('Game Night Guest', 'Invitado a la noche de juegos'),
    ('Played during a game night.', 'Jugaste en una noche de juegos.'),
    (s) => s.results.any((r) => r.nightId != null),
  ),
  FriendlyAchievement(
    'team',
    '🤝',
    ('Team Player', 'Jugador de equipo'),
    (
      'Played 3 games during game nights.',
      'Jugaste 3 juegos en noches de juegos.',
    ),
    (s) => s.results.where((r) => r.nightId != null).length >= 3,
  ),
  FriendlyAchievement(
    'perfect',
    '⭐',
    ('Perfect Round', 'Ronda perfecta'),
    (
      'Got every answer right in a scored game.',
      'Acertaste todo en un juego con puntos.',
    ),
    (s) => s.results.any(
      (r) => r.score != null && r.max != null && r.max! > 0 && r.score == r.max,
    ),
  ),
  FriendlyAchievement(
    'story',
    '📜',
    ('Storyteller', 'Cuentacuentos'),
    (
      'Added to a story, poem or world.',
      'Contribuiste a una historia, poema o mundo.',
    ),
    (s) =>
        s.playedOf(const [
          'story_chain',
          'collab_poetry',
          'worldbuilder',
          'build_story',
          'poetry_generator',
        ]) >
        0,
  ),
  FriendlyAchievement(
    'artist',
    '🖌️',
    ('Artist', 'Artista'),
    ('Finished 3 drawings or scenes.', 'Terminaste 3 dibujos o escenas.'),
    (s) =>
        s.playedOf(
          gameCatalog
              .where(
                (g) =>
                    g.style == PlayStyle.create &&
                    g.category == GameCategory.cozy,
              )
              .map((g) => g.id),
        ) >=
        3,
  ),
  FriendlyAchievement(
    'maker',
    '🛠️',
    ('Game Maker', 'Creador de juegos'),
    ('Made a custom game.', 'Creaste un juego personalizado.'),
    (s) => s.customMade > 0,
  ),
  FriendlyAchievement(
    'kind',
    '💌',
    ('Kind Words', 'Palabras amables'),
    ('Made a postcard.', 'Hiciste una postal.'),
    (s) => s.playedOf(const ['postcard']) > 0,
  ),
  FriendlyAchievement(
    'steady',
    '🍵',
    ('Comfortable Habit', 'Costumbre agradable'),
    (
      'Played on 7 different days — any days, no streak needed.',
      'Jugaste 7 días distintos, sin necesidad de rachas.',
    ),
    (s) => s.days >= 7,
  ),
];

/// One alter's stats ('' = played without choosing an alter).
final gameStatsProvider = Provider.family<GameStats, String>((ref, memberId) {
  final results = [
    for (final r in ref.watch(gameResultsProvider))
      if ((r.memberId ?? '') == memberId) r,
  ];
  final made = ref
      .watch(customGamesProvider)
      .where((c) => (c.creator ?? '') == memberId)
      .length;
  return GameStats(results, customMade: made);
});

/// The "Profiles" tab: choose an alter to see their recreation profile.
class GamesProfilesView extends ConsumerStatefulWidget {
  const GamesProfilesView({super.key});
  @override
  ConsumerState<GamesProfilesView> createState() => _GamesProfilesViewState();
}

class _GamesProfilesViewState extends ConsumerState<GamesProfilesView> {
  String? _member;
  @override
  Widget build(BuildContext context) {
    final members = ref.watch(gameMembersProvider);
    final names = ref.watch(gameNamesProvider);
    final id =
        _member ??
        ref.watch(gamePlayerDefaultProvider) ??
        members.firstOrNull?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(
                    avatar: AlterDot(m.id, size: 22),
                    label: names[m.id] ?? '',
                    selected: id == m.id,
                    onTap: () => setState(() => _member = m.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (id == null)
          EmptyState(
            icon: Icon(PhosphorIcons.user()),
            title: tr(context, 'No alters yet', 'Aún no hay alters'),
            subtitle: tr(
              context,
              'Add members to give them Games profiles.',
              'Añade miembros para darles perfiles de juegos.',
            ),
          )
        else
          AlterGamesProfile(memberId: id, full: true),
      ],
    );
  }
}

/// An alter's Games profile. [full] adds settings (hide stats, clues).
/// Also used as the optional "Games" module on member profiles.
class AlterGamesProfile extends ConsumerWidget {
  const AlterGamesProfile({
    super.key,
    required this.memberId,
    this.full = false,
  });
  final String memberId;
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile =
        ref.watch(gameProfilesProvider)[memberId] ?? const GameProfile();
    final stats = ref.watch(gameStatsProvider(memberId));
    final earned = friendlyAchievements.where((a) => a.check(stats)).toList();
    final hidden = profile.hideStats;
    final favs = [for (final f in profile.favorites) ?gameById(f)];
    final memorable =
        stats.results.where((r) => (r.memorable ?? '').isNotEmpty).toList()
          ..sort((a, b) => b.when.compareTo(a.when));
    final best = <String, GameResult>{};
    for (final r in stats.results) {
      if (r.ratio == null) continue;
      final b = best[r.gameId];
      if (b == null || r.ratio! > b.ratio!) best[r.gameId] = r;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hidden && !full)
          PrismSurface(
            child: Text(
              tr(
                context,
                'Game stats are hidden on this profile.',
                'Las estadísticas de juegos están ocultas en este perfil.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          )
        else ...[
          PrismSurface(
            child: Row(
              children: [
                _Stat(
                  value: '${stats.results.length}',
                  label: tr(context, 'games played', 'partidas'),
                ),
                _Stat(
                  value: '${stats.distinct.length}',
                  label: tr(context, 'different games', 'juegos distintos'),
                ),
                _Stat(
                  value: stats.favouriteCategory?.emoji ?? '—',
                  label: stats.favouriteCategory == null
                      ? tr(context, 'favourite type', 'tipo favorito')
                      : trp(context, stats.favouriteCategory!.label),
                ),
              ],
            ),
          ),
          if (hidden)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr(
                  context,
                  'Only visible here — hidden on the member profile.',
                  'Solo visible aquí: oculto en el perfil del miembro.',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          PrismSectionHeader(
            title: tr(
              context,
              'FRIENDLY ACHIEVEMENTS · ${earned.length}/${friendlyAchievements.length}',
              'LOGROS AMISTOSOS · ${earned.length}/${friendlyAchievements.length}',
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in full ? friendlyAchievements : earned)
                Semantics(
                  label:
                      '${trp(context, a.name)}: ${trp(context, a.desc)}${earned.contains(a) ? '' : ' (${tr(context, 'not yet', 'aún no')})'}',
                  excludeSemantics: true,
                  child: Opacity(
                    opacity: earned.contains(a) ? 1 : 0.35,
                    child: Tooltip(
                      message:
                          '${trp(context, a.name)} — ${trp(context, a.desc)}',
                      child: Container(
                        width: 92,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: prismCorners(context, 14),
                        ),
                        child: Column(
                          children: [
                            Text(a.emoji, style: const TextStyle(fontSize: 24)),
                            Text(
                              trp(context, a.name),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (!full && earned.isEmpty)
                Text(
                  tr(
                    context,
                    'None yet — play anything to begin.',
                    'Ninguno aún: juega lo que quieras.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          if (best.isNotEmpty) ...[
            PrismSectionHeader(
              title: tr(context, 'PERSONAL BESTS', 'MEJORES MARCAS'),
            ),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final r
                      in (best.values.toList()
                            ..sort((a, b) => b.ratio!.compareTo(a.ratio!)))
                          .take(full ? 8 : 4))
                    PrismListRow(
                      dense: true,
                      leading: Text(gameById(r.gameId)?.emoji ?? '🎲'),
                      title: Text(
                        trp(
                          context,
                          gameById(r.gameId)?.name ?? (r.gameId, r.gameId),
                        ),
                      ),
                      trailing: Text(
                        '${r.score}/${r.max}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (memorable.isNotEmpty) ...[
            PrismSectionHeader(
              title: tr(context, 'MEMORABLE MOMENTS', 'MOMENTOS MEMORABLES'),
            ),
            for (final r in memorable.take(full ? 5 : 2))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${gameById(r.gameId)?.emoji ?? ''} "${r.memorable}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ],
        if (favs.isNotEmpty) ...[
          PrismSectionHeader(
            title: tr(context, 'FAVOURITE GAMES', 'JUEGOS FAVORITOS'),
          ),
          GameRow(games: favs),
        ],
        if (full) ...[
          PrismSectionHeader(title: tr(context, 'PRIVACY', 'PRIVACIDAD')),
          PrismSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: PrismSwitchRow(
              title: tr(
                context,
                'Hide game stats on my profile',
                'Ocultar estadísticas en mi perfil',
              ),
              subtitle: tr(
                context,
                'Achievements, scores and moments won\'t show on the member profile.',
                'Los logros, puntuaciones y momentos no se mostrarán en el perfil.',
              ),
              value: hidden,
              onChanged: (v) =>
                  ref.read(gamesActionsProvider).setHideStats(memberId, v),
            ),
          ),
          PrismSectionHeader(
            title: tr(
              context,
              'CLUES FOR GUESS THE ALTER',
              'PISTAS PARA ADIVINA EL ALTER',
            ),
          ),
          Text(
            tr(
              context,
              'Only share what you\'re comfortable with. Clues are used only in Guess the Alter.',
              'Comparte solo lo que te resulte cómodo. Las pistas solo se usan en Adivina el alter.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < profile.clues.length; i++)
            PrismListRow(
              dense: true,
              title: Text(profile.clues[i]),
              trailing: PrismIconButton(
                icon: PhosphorIcons.x(),
                tooltip: tr(context, 'Remove', 'Quitar'),
                onPressed: () => ref
                    .read(gamesActionsProvider)
                    .setClues(memberId, [...profile.clues]..removeAt(i)),
              ),
            ),
          PrismButton(
            icon: PhosphorIcons.plus(),
            label: tr(context, 'Add a clue', 'Añadir pista'),
            onPressed: () async {
              final t = await promptText(
                context,
                title: tr(context, 'A clue about you', 'Una pista sobre ti'),
                hint: tr(
                  context,
                  'e.g. "I love thunderstorms"',
                  'p. ej. "Me encantan las tormentas"',
                ),
              );
              if (t != null && t.isNotEmpty)
                await ref.read(gamesActionsProvider).setClues(memberId, [
                  ...profile.clues,
                  t,
                ]);
            },
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}
