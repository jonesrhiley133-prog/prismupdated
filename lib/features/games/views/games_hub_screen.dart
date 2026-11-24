import 'dart:math' as math;

import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/views/custom_games_view.dart';
import 'package:prism_plurality/features/games/views/game_night_view.dart';
import 'package:prism_plurality/features/games/views/games_profile_view.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart' show FeatureDataAction;
import 'package:prism_plurality/shared/ui_kit.dart';

enum GamesTab { play, challenges, nights, create, me }

class GamesHubScreen extends ConsumerStatefulWidget {
  const GamesHubScreen({super.key, this.tab});
  final String? tab;
  @override
  ConsumerState<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends ConsumerState<GamesHubScreen> {
  late GamesTab _tab = GamesTab.values.where((t) => t.name == widget.tab).firstOrNull ?? GamesTab.play;

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(openChallengesProvider).length;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Games', 'Juegos'),
        actions: [
          PrismTopBarAction(icon: PhosphorIcons.shuffle(), tooltip: tr(context, 'Random game', 'Juego al azar'), onPressed: () => openRandomGame(context)),
          const FeatureDataAction(featureId: 'games'),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSegmentedControl<GamesTab>(
              segments: [
                PrismSegment(value: GamesTab.play, label: tr(context, 'Play', 'Jugar')),
                PrismSegment(value: GamesTab.challenges, label: waiting == 0 ? tr(context, 'Challenges', 'Retos') : '${tr(context, 'Challenges', 'Retos')} · $waiting'),
                PrismSegment(value: GamesTab.nights, label: tr(context, 'Game Night', 'Noche de juegos')),
                PrismSegment(value: GamesTab.create, label: tr(context, 'Create', 'Crear')),
                PrismSegment(value: GamesTab.me, label: tr(context, 'Profiles', 'Perfiles')),
              ],
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 14),
            SectionSwitcher(
              id: _tab,
              child: switch (_tab) {
                GamesTab.play => const _PlayTab(),
                GamesTab.challenges => const _ChallengesTab(),
                GamesTab.nights => const GameNightsView(),
                GamesTab.create => const CustomGamesView(),
                GamesTab.me => const GamesProfilesView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

void openGame(BuildContext context, String id, {String? challenge, String? custom, String? night}) => context.push(AppRoutePaths.gamePlay(id, challenge: challenge, custom: custom, night: night));

void openRandomGame(BuildContext context, {bool Function(GameDef)? where}) {
  final pool = gameCatalog.where(where ?? (_) => true).toList();
  if (pool.isEmpty) return;
  openGame(context, pool[math.Random().nextInt(pool.length)].id);
}

/// Challenges whose recipients haven't all played yet.
final openChallengesProvider = Provider<List<GameChallenge>>((ref) {
  final results = ref.watch(gameResultsProvider);
  return [
    for (final c in ref.watch(gameChallengesProvider))
      if (c.to.isEmpty ? !results.any((r) => r.challengeId == c.r.id) : c.to.any((m) => !results.any((r) => r.challengeId == c.r.id && r.memberId == m))) c,
  ]..sort((a, b) => b.when.compareTo(a.when));
});

// ---------------------------------------------------------------------------
// Play tab
// ---------------------------------------------------------------------------

enum _Sort { featured, az, shortest, recent }

class _PlayTab extends ConsumerStatefulWidget {
  const _PlayTab();
  @override
  ConsumerState<_PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends ConsumerState<_PlayTab> {
  final _search = TextEditingController();
  GameCategory? _cat;
  String? _tag;
  bool _multi = false;
  _Sort _sort = _Sort.featured;

  static const _tags = {
    'quick': ('⚡ Quick', '⚡ Rápidos'),
    'relaxing': ('🌿 Relaxing', '🌿 Relajantes'),
    'party': ('🎉 Party', '🎉 Fiesta'),
    'educational': ('🎓 Learning', '🎓 Aprender'),
    'collaborative': ('🤝 Together', '🤝 Juntos'),
    'daily': ('📅 Daily', '📅 Diarios'),
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtering => _search.text.trim().isNotEmpty || _cat != null || _tag != null || _multi || _sort != _Sort.featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = ref.watch(gameResultsProvider);
    final lastPlayed = <String, DateTime>{};
    for (final r in results) {
      final w = lastPlayed[r.gameId];
      if (w == null || r.when.isAfter(w)) lastPlayed[r.gameId] = r.when;
    }
    final q = _search.text.trim().toLowerCase();
    var list = gameCatalog.where((g) {
      if (_cat != null && g.category != _cat) return false;
      if (_tag != null && !g.tags.contains(_tag)) return false;
      if (_multi && !g.multiplayer) return false;
      if (q.isEmpty) return true;
      return '${g.name.$1} ${g.name.$2} ${g.desc.$1} ${g.number}'.toLowerCase().contains(q);
    }).toList();
    switch (_sort) {
      case _Sort.az:
        list.sort((a, b) => trp(context, a.name).compareTo(trp(context, b.name)));
      case _Sort.shortest:
        list.sort((a, b) => a.minutes.compareTo(b.minutes));
      case _Sort.recent:
        list.sort((a, b) => (lastPlayed[b.id] ?? DateTime(1970)).compareTo(lastPlayed[a.id] ?? DateTime(1970)));
      case _Sort.featured:
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismTextField(controller: _search, hintText: tr(context, 'Search 120 games', 'Buscar entre 120 juegos'), prefixIcon: Icon(PhosphorIcons.magnifyingGlass()), onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in GameCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(label: '${c.emoji} ${trp(context, c.label)}', selected: _cat == c, onTap: () => setState(() => _cat = _cat == c ? null : c)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in _tags.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PrismChip(label: trp(context, e.value), selected: _tag == e.key, onTap: () => setState(() => _tag = _tag == e.key ? null : e.key)),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PrismChip(label: tr(context, '👥 Multiplayer', '👥 Multijugador'), selected: _multi, onTap: () => setState(() => _multi = !_multi)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(tr(context, 'Sort', 'Ordenar'), style: theme.textTheme.labelMedium),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (s, l) in [
                      (_Sort.featured, tr(context, 'Featured', 'Destacados')),
                      (_Sort.az, 'A–Z'),
                      (_Sort.shortest, tr(context, 'Shortest', 'Más cortos')),
                      (_Sort.recent, tr(context, 'Recently played', 'Jugados hace poco')),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: PrismChip(label: l, selected: _sort == s, onTap: () => setState(() => _sort = s)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_filtering) ...[
          PrismSectionHeader(title: tr(context, '${list.length} GAMES', '${list.length} JUEGOS')),
          if (list.isEmpty)
            EmptyState(
              icon: Icon(PhosphorIcons.gameController()),
              title: tr(context, 'No games match', 'Ningún juego coincide'),
              subtitle: tr(context, 'Try another word or clear a filter.', 'Prueba otra palabra o quita un filtro.'),
            )
          else
            GameGrid(games: list),
          if (list.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PrismButton(
                icon: PhosphorIcons.shuffle(),
                label: tr(context, 'Random from these', 'Uno al azar de estos'),
                onPressed: () => openGame(context, list[math.Random().nextInt(list.length)].id),
              ),
            ),
        ] else
          const _Featured(),
      ],
    );
  }
}

class _Featured extends ConsumerWidget {
  const _Featured();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(gameResultsProvider);
    final saves = ref.watch(gameSavesProvider);
    final fronter = ref.watch(gamePlayerDefaultProvider);
    final profiles = ref.watch(gameProfilesProvider);
    final open = ref.watch(openChallengesProvider);

    final continuing = [
      for (final s in [...saves]..sort((a, b) => (b.occurredAt ?? b.createdAt).compareTo(a.occurredAt ?? a.createdAt)))
        if (gameById(s.title) != null) gameById(s.title)!,
    ].toSet().toList();
    final recent = <GameDef>[];
    for (final r in [...results]..sort((a, b) => b.when.compareTo(a.when))) {
      final g = gameById(r.gameId);
      if (g != null && !recent.contains(g)) recent.add(g);
      if (recent.length >= 10) break;
    }
    final favIds = {...?profiles[fronter ?? '']?.favorites, ...?profiles['']?.favorites};
    final favs = [for (final id in favIds) ?gameById(id)];
    // Recommended: categories played most, games not yet played.
    final catCount = <GameCategory, int>{};
    for (final r in results) {
      final g = gameById(r.gameId);
      if (g != null) catCount[g.category] = (catCount[g.category] ?? 0) + 1;
    }
    final played = {for (final r in results) r.gameId};
    final cats = [...GameCategory.values]..sort((a, b) => (catCount[b] ?? 0).compareTo(catCount[a] ?? 0));
    final rng = math.Random(dailySeed());
    final recommended = [for (final c in cats.take(3)) ...(gameCatalog.where((g) => g.category == c && !played.contains(g.id)).toList()..shuffle(rng)).take(2)];
    final quick = gameCatalog.where((g) => g.tags.contains('quick')).toList()..shuffle(rng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (open.isNotEmpty)
          PrismSurface(
            tone: PrismSurfaceTone.accent,
            child: Row(
              children: [
                Icon(PhosphorIcons.paperPlaneTilt()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(
                      context,
                      '${open.length} challenge${open.length == 1 ? '' : 's'} waiting — play whenever you like.',
                      '${open.length} reto${open.length == 1 ? '' : 's'} pendiente${open.length == 1 ? '' : 's'}: juega cuando quieras.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (continuing.isNotEmpty) ...[PrismSectionHeader(title: tr(context, 'CONTINUE PLAYING', 'CONTINUAR')), GameRow(games: continuing)],
        PrismSectionHeader(title: tr(context, 'TODAY', 'HOY')),
        GameRow(games: dailyGames()),
        if (favs.isNotEmpty) ...[PrismSectionHeader(title: tr(context, 'FAVOURITES', 'FAVORITOS')), GameRow(games: favs)],
        if (recent.isNotEmpty) ...[PrismSectionHeader(title: tr(context, 'RECENTLY PLAYED', 'JUGADOS HACE POCO')), GameRow(games: recent)],
        PrismSectionHeader(title: tr(context, 'RECOMMENDED', 'RECOMENDADOS')),
        GameRow(games: recommended),
        PrismSectionHeader(title: tr(context, 'QUICK PLAY', 'PARTIDA RÁPIDA')),
        GameRow(games: quick.take(10).toList()),
        for (final c in GameCategory.values) ...[PrismSectionHeader(title: '${c.emoji} ${trp(context, c.label).toUpperCase()}'), GameRow(games: gameCatalog.where((g) => g.category == c).toList())],
      ],
    );
  }
}

/// Horizontal row of game cards.
class GameRow extends StatelessWidget {
  const GameRow({super.key, required this.games});
  final List<GameDef> games;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: games.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) => SizedBox(width: 132, child: GameCard(def: games[i])),
    ),
  );
}

/// Responsive grid of game cards.
class GameGrid extends StatelessWidget {
  const GameGrid({super.key, required this.games});
  final List<GameDef> games;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = math.max(2, (box.maxWidth / 150).floor());
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: games.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 150),
        itemBuilder: (context, i) => GameCard(def: games[i]),
      );
    },
  );
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.def, this.onTap});
  final GameDef def;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${trp(context, def.name)}. ${trp(context, def.desc)}',
      excludeSemantics: true,
      child: PrismSurface(
        padding: const EdgeInsets.all(12),
        onTap: onTap ?? () => openGame(context, def.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(def.emoji, style: const TextStyle(fontSize: 28)),
                const Spacer(),
                if (def.multiplayer) Icon(PhosphorIcons.users(), size: 14, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              trp(context, def.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
            ),
            const Spacer(),
            Text('~${def.minutes} min · ${difficultyLabel(context, def.difficulty)}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenges
// ---------------------------------------------------------------------------

class _ChallengesTab extends ConsumerWidget {
  const _ChallengesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openChallengesProvider);
    final all = ref.watch(gameChallengesProvider);
    final names = ref.watch(gameNamesProvider);
    final results = ref.watch(gameResultsProvider);
    final done = all.where((c) => !open.contains(c)).toList()..sort((a, b) => b.when.compareTo(a.when));
    final theme = Theme.of(context);

    Widget tile(GameChallenge c, {required bool isOpen}) {
      final g = gameById(c.gameId);
      final played = [
        for (final r in results)
          if (r.challengeId == c.r.id || (r.gameId == c.gameId && r.memberId == c.from && r.challengeId == null && (r.when.difference(c.when).inMinutes.abs() < 5))) r,
      ];
      return PrismListRow(
        leading: Text(g?.emoji ?? '🎲', style: const TextStyle(fontSize: 26)),
        title: Text(g == null ? c.gameId : trp(context, g.name)),
        subtitle: Text(
          [
            '${names[c.from] ?? tr(context, 'Someone', 'Alguien')} → ${c.to.isEmpty ? tr(context, 'anyone', 'cualquiera') : c.to.map((m) => names[m] ?? '?').join(', ')}',
            if (c.message.isNotEmpty) '"${c.message}"',
            if (played.isNotEmpty) played.map((r) => '${names[r.memberId] ?? '?'}: ${r.score ?? '✓'}${r.max == null ? '' : '/${r.max}'}').join(' · '),
          ].join('\n'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOpen)
              PrismButton(
                density: PrismControlDensity.compact,
                tone: PrismButtonTone.filled,
                label: tr(context, 'Play', 'Jugar'),
                onPressed: () => openGame(context, c.gameId, challenge: c.r.id),
              ),
            PrismIconButton(icon: PhosphorIcons.trash(), tooltip: tr(context, 'Remove', 'Quitar'), onPressed: () => ref.read(gamesActionsProvider).delete(c.r)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Challenges let alters play the same puzzle at different times. Finish a game and choose "Challenge another alter", or start one here.',
            'Los retos permiten jugar el mismo puzle en momentos distintos. Al terminar un juego elige "Retar a otro alter", o empieza uno aquí.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        PrismButton(icon: PhosphorIcons.plus(), label: tr(context, 'New challenge', 'Nuevo reto'), onPressed: () => _newChallenge(context, ref)),
        PrismSectionHeader(title: tr(context, 'WAITING', 'PENDIENTES')),
        if (open.isEmpty)
          EmptyState(
            icon: Icon(PhosphorIcons.paperPlaneTilt()),
            title: tr(context, 'No open challenges', 'No hay retos pendientes'),
            subtitle: tr(context, 'Nothing to catch up on — no pressure.', 'Nada pendiente, sin presión.'),
          )
        else
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [for (final c in open) tile(c, isOpen: true)]),
          ),
        if (done.isNotEmpty) ...[
          PrismSectionHeader(title: tr(context, 'COMPLETED', 'COMPLETADOS')),
          PrismSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [for (final c in done.take(20)) tile(c, isOpen: false)]),
          ),
        ],
      ],
    );
  }

  Future<void> _newChallenge(BuildContext context, WidgetRef ref) async {
    final g = await pickGame(context, where: (g) => g.seeded && g.style == PlayStyle.turns);
    if (g == null || !context.mounted) return;
    final from = await pickAlters(context, ref, max: 1, title: tr(context, 'Who is sending it?', '¿Quién lo envía?'), selected: [?ref.read(gamePlayerDefaultProvider)]);
    if (from == null || !context.mounted) return;
    final to = await pickAlters(context, ref, title: tr(context, 'Who should take it?', '¿Quién lo acepta?'));
    if (to == null || to.isEmpty || !context.mounted) return;
    final msg = await promptText(context, title: tr(context, 'Add a note (optional)', 'Añade una nota (opcional)'));
    await ref.read(gamesActionsProvider).createChallenge(gameId: g.id, from: from.firstOrNull, to: to, seed: math.Random().nextInt(1 << 30), message: msg ?? '');
    if (context.mounted) PrismToast.show(context, message: tr(context, 'Challenge sent', 'Reto enviado'));
  }
}

/// A searchable game picker sheet.
Future<GameDef?> pickGame(BuildContext context, {bool Function(GameDef)? where, String? title}) {
  return PrismSheet.show<GameDef>(
    context: context,
    title: title ?? tr(context, 'Choose a game', 'Elige un juego'),
    builder: (ctx) => _GamePicker(where: where),
  );
}

class _GamePicker extends StatefulWidget {
  const _GamePicker({this.where});
  final bool Function(GameDef)? where;
  @override
  State<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends State<_GamePicker> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final list = gameCatalog.where((g) => (widget.where?.call(g) ?? true) && (q.isEmpty || '${g.name.$1} ${g.name.$2}'.toLowerCase().contains(q))).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrismTextField(controller: _q, hintText: tr(context, 'Search', 'Buscar'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          SizedBox(
            height: math.min(420, MediaQuery.sizeOf(context).height * 0.55),
            child: ListView(
              children: [
                for (final g in list)
                  PrismListRow(
                    leading: Text(g.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(trp(context, g.name)),
                    subtitle: Text(trp(context, g.category.label)),
                    onTap: () => Navigator.of(context).pop(g),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple one-field text prompt.
Future<String?> promptText(BuildContext context, {required String title, String initial = '', String? hint, int maxLines = 2}) {
  final ctl = TextEditingController(text: initial);
  return PrismSheet.show<String>(
    context: context,
    title: title,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrismTextField(controller: ctl, hintText: hint, maxLines: maxLines, autofocus: true),
          const SizedBox(height: 12),
          PrismButton(tone: PrismButtonTone.filled, label: tr(ctx, 'Done', 'Hecho'), onPressed: () => Navigator.of(ctx).pop(ctl.text.trim())),
        ],
      ),
    ),
  ).whenComplete(ctl.dispose);
}
