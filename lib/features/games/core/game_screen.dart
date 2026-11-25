import 'dart:async';
import 'dart:math' as math;

import 'package:prism_plurality/features/voice/voice_engine.dart';
import 'package:prism_plurality/features/games/core/game_catalog.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Wraps a deferred library so a game's code and content load only when
/// the game opens.
class LazyGame extends StatefulWidget {
  const LazyGame({super.key, required this.load, required this.builder});
  final Future<void> Function() load;
  final WidgetBuilder builder;
  @override
  State<LazyGame> createState() => _LazyGameState();
}

class _LazyGameState extends State<LazyGame> {
  late final Future<void> _f = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _f,
    builder: (context, s) => s.connectionState == ConnectionState.done
        ? (s.hasError
              ? Center(child: Text('${s.error}'))
              : widget.builder(context))
        : const Padding(
            padding: EdgeInsets.all(40),
            child: PrismLoadingState(),
          ),
  );
}

enum _Stage { setup, play, handoff, results }

/// Hosts any game: setup → play (with pass & play turns) → results.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.gameId,
    this.challengeId,
    this.players,
    this.seed,
    this.custom,
    this.customTitle,
    this.onComplete,
    this.nightId,
  });
  final String gameId;
  final String? challengeId;
  final List<String>? players;
  final int? seed;
  final Map<String, Object?>? custom;
  final String? customTitle;
  final String? nightId;

  /// Game Night: called with each alter's outcome instead of showing the
  /// usual results actions.
  final void Function(Map<String, GameOutcome> outcomes)? onComplete;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  _Stage _stage = _Stage.setup;
  late List<String> _players;
  late int _seed;
  bool _timer = false;
  int _turn = 0;
  final Map<String, GameOutcome> _outcomes = {};
  GameOutcome? _lastAnon;
  Map<String, Object?>? _restored;
  Timer? _debounce;
  Map<String, Object?>? _pending;
  int _round = 0;

  GameDef? get def => gameById(widget.gameId);
  GameChallenge? get challenge => widget.challengeId == null
      ? null
      : ref
            .read(gameChallengesProvider)
            .where((c) => c.r.id == widget.challengeId)
            .firstOrNull;

  @override
  void initState() {
    super.initState();
    final c = challenge;
    final fronter = ref.read(gamePlayerDefaultProvider);
    _players = widget.players ?? (fronter == null ? <String>[] : [fronter]);
    if (c != null && c.to.isNotEmpty && widget.players == null)
      _players = [c.to.first];
    _seed =
        widget.seed ??
        c?.seed ??
        (def?.tags.contains('daily') == true
            ? dailySeed()
            : math.Random().nextInt(1 << 30));
  }

  @override
  void dispose() {
    _flushSave();
    _debounce?.cancel();
    super.dispose();
  }

  String? get _current {
    final d = def;
    if (d == null) return null;
    if (_players.isEmpty) return null;
    if (d.style != PlayStyle.turns) return _players.first;
    return _players[_turn.clamp(0, _players.length - 1)];
  }

  void _queueSave(Map<String, Object?> state) {
    if (def?.saves != true ||
        widget.challengeId != null ||
        widget.custom != null)
      return;
    _pending = state;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _flushSave);
  }

  void _flushSave() {
    final s = _pending;
    if (s == null) return;
    _pending = null;
    ref
        .read(gamesActionsProvider)
        .writeSave(widget.gameId, _current, s, seed: _seed);
  }

  Future<void> _finish(GameOutcome o) async {
    final d = def!;
    _debounce?.cancel();
    _pending = null;
    final who = _current;
    if (d.saves)
      await ref.read(gamesActionsProvider).clearSave(widget.gameId, who);
    await ref
        .read(gamesActionsProvider)
        .recordResult(
          gameId: widget.gameId,
          memberId: who,
          score: o.score,
          max: o.max,
          summary: o.summary,
          memorable: o.memorable,
          challengeId: widget.challengeId,
          nightId: widget.nightId,
        );
    if (!mounted) return;
    setState(() {
      if (who != null) {
        _outcomes[who] = o;
      } else {
        _lastAnon = o;
      }
      if (d.style == PlayStyle.turns && _turn + 1 < _players.length) {
        _turn++;
        _stage = _Stage.handoff;
      } else {
        _stage = _Stage.results;
        if (widget.onComplete != null) {
          widget.onComplete!({
            ..._outcomes,
            if (_lastAnon != null) '': _lastAnon!,
          });
        }
      }
    });
  }

  void _start({bool resume = false}) {
    final d = def!;
    _restored = null;
    if (resume) {
      final save = ref.read(gamesActionsProvider).saveFor(d.id, _current);
      _restored = (save?.fields['state'] as Map?)?.cast<String, Object?>();
      final s = (save?.fields['seed'] as num?)?.toInt();
      if (s != null) _seed = s;
    } else if (d.saves && widget.challengeId == null) {
      ref.read(gamesActionsProvider).clearSave(d.id, _current);
    }
    setState(() {
      _turn = 0;
      _outcomes.clear();
      _lastAnon = null;
      _round++;
      _stage = _Stage.play;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = def;
    if (d == null) {
      return PrismPageScaffold(
        topBar: const PrismTopBar(title: 'Games'),
        body: EmptyState(
          icon: Icon(PhosphorIcons.question()),
          title: tr(context, 'Game not found', 'Juego no encontrado'),
          subtitle: widget.gameId,
        ),
      );
    }
    final names = ref.watch(gameNamesProvider);
    final favs =
        ref.watch(gameProfilesProvider)[_current ?? '']?.favorites ?? const [];
    final title = widget.customTitle ?? trp(context, d.name);
    return PopScope(
      canPop: _stage != _Stage.play,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage == _Stage.play) {
          _flushSave();
          setState(() => _stage = _Stage.setup);
        }
      },
      child: PrismPageScaffold(
        topBar: PrismTopBar(
          title: title,
          subtitle: _stage == _Stage.play && _current != null
              ? names[_current]
              : trp(context, d.category.label),
          leading: _stage == _Stage.play
              ? PrismTopBarAction(
                  icon: PhosphorIcons.pause(),
                  tooltip: d.saves
                      ? tr(context, 'Pause & save', 'Pausar y guardar')
                      : tr(context, 'Stop', 'Parar'),
                  onPressed: () {
                    _flushSave();
                    setState(() => _stage = _Stage.setup);
                  },
                )
              : null,
          actions: [
            PrismTopBarAction(
              icon: PhosphorIcons.question(),
              tooltip: tr(context, 'How to play', 'Cómo se juega'),
              onPressed: () => _showHowTo(context, d),
            ),
            PrismTopBarAction(
              icon: favs.contains(d.id)
                  ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                  : PhosphorIcons.heart(),
              tooltip: tr(context, 'Favourite', 'Favorito'),
              onPressed: () =>
                  ref.read(gamesActionsProvider).toggleFavorite(d.id, _current),
            ),
          ],
        ),
        topBarMaxWidth: PrismTokens.contentMaxWidth,
        bodyPadding: EdgeInsets.zero,
        body: ClampedBody(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32 + NavBarInset.of(context),
            ),
            children: [
              switch (_stage) {
                _Stage.setup => _setup(context, d),
                _Stage.play => KeyedSubtree(
                  key: ValueKey('$_round/$_turn'),
                  child: d.build(
                    GameSession(
                      def: d,
                      player: _current,
                      players: _players,
                      names: names,
                      seed: _seed,
                      saved: _restored,
                      timer: _timer,
                      custom: widget.custom,
                      save: _queueSave,
                      finish: _finish,
                    ),
                  ),
                ),
                _Stage.handoff => _handoff(context, names),
                _Stage.results => _results(context, d, names),
              },
            ],
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, GameDef d) => PrismSheet.show(
    context: context,
    title: tr(context, 'How to play', 'Cómo se juega'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Text(trp(ctx, d.howTo), style: const TextStyle(height: 1.5)),
    ),
  );

  Widget _setup(BuildContext context, GameDef d) {
    final theme = Theme.of(context);
    final save = d.saves && widget.challengeId == null && widget.custom == null
        ? ref
              .watch(gameSavesProvider)
              .where((r) => r.title == d.id && r.memberId == _current)
              .firstOrNull
        : null;
    final c = challenge;
    final names = ref.watch(gameNamesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(d.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      trp(context, d.desc),
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Meta(PhosphorIcons.clock(), '~${d.minutes} min'),
                  _Meta(PhosphorIcons.users(), playersLabel(context, d)),
                  _Meta(
                    PhosphorIcons.gauge(),
                    difficultyLabel(context, d.difficulty),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                trp(context, d.howTo),
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (c != null) ...[
          const SizedBox(height: 12),
          PrismSurface(
            tone: PrismSurfaceTone.accent,
            child: Text(
              '${tr(context, 'Challenge from', 'Reto de')} ${names[c.from] ?? tr(context, 'someone', 'alguien')}${c.message.isEmpty ? '' : ': "${c.message}"'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        PrismSectionHeader(
          title: d.maxPlayers > 1
              ? tr(context, 'WHO\'S PLAYING', 'QUIÉN JUEGA')
              : tr(context, 'PLAYING AS', 'JUEGA'),
        ),
        AlterChips(
          ids: _players,
          onTap: () async {
            final p = await pickAlters(
              context,
              ref,
              selected: _players,
              max: d.maxPlayers,
            );
            if (p != null) setState(() => _players = p);
          },
        ),
        if (d.style == PlayStyle.turns && _players.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr(
                context,
                'Pass & play: each alter gets the same puzzle in turn, then you compare. You can stop between turns.',
                'Por turnos: cada alter juega el mismo reto y luego comparáis. Podéis parar entre turnos.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (d.timerOption)
          PrismSwitchRow(
            padding: const EdgeInsets.symmetric(vertical: 10),
            title: tr(context, 'Use a timer', 'Usar temporizador'),
            subtitle: tr(
              context,
              'Optional — every game can be played untimed.',
              'Opcional: todos los juegos se pueden jugar sin tiempo.',
            ),
            value: _timer,
            onChanged: (v) => setState(() => _timer = v),
          ),
        const SizedBox(height: 16),
        if (save != null) ...[
          PrismButton(
            tone: PrismButtonTone.filled,
            expanded: true,
            icon: PhosphorIcons.play(),
            label: tr(
              context,
              'Continue where you left off',
              'Continuar donde lo dejaste',
            ),
            onPressed: () => _start(resume: true),
          ),
          const SizedBox(height: 8),
          PrismButton(
            expanded: true,
            icon: PhosphorIcons.arrowCounterClockwise(),
            label: tr(context, 'Start over', 'Empezar de nuevo'),
            onPressed: () => _start(),
          ),
        ] else
          PrismButton(
            tone: PrismButtonTone.filled,
            expanded: true,
            icon: PhosphorIcons.play(),
            label: c != null
                ? tr(context, 'Accept challenge', 'Aceptar reto')
                : tr(context, 'Play', 'Jugar'),
            onPressed: () => _start(),
          ),
      ],
    );
  }

  Widget _handoff(BuildContext context, Map<String, String> names) {
    final next = _players[_turn];
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          AlterDot(next, size: 72),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Pass to ${names[next]}', 'Pasa a ${names[next]}'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Same puzzle, their turn. Results are saved — they can play now or later.',
              'Mismo reto, su turno. Los resultados se guardan: puede jugar ahora o más tarde.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrismButton(
            tone: PrismButtonTone.filled,
            label: tr(
              context,
              'Start ${names[next]}\'s turn',
              'Empezar turno de ${names[next]}',
            ),
            onPressed: () => setState(() => _stage = _Stage.play),
          ),
          const SizedBox(height: 8),
          PrismButton(
            label: tr(
              context,
              'Later — leave it as a challenge',
              'Más tarde: dejarlo como reto',
            ),
            onPressed: () async {
              await ref
                  .read(gamesActionsProvider)
                  .createChallenge(
                    gameId: widget.gameId,
                    from: _players.first,
                    to: _players.sublist(_turn),
                    seed: _seed,
                  );
              if (mounted) setState(() => _stage = _Stage.results);
            },
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, GameDef d, Map<String, String> names) {
    final theme = Theme.of(context);
    final entries = [
      ..._outcomes.entries.map((e) => (e.key, e.value)),
      if (_lastAnon != null) ('', _lastAnon!),
    ];
    final scored = entries.where((e) => e.$2.scored).toList();
    // Earlier results for the same challenge (async play).
    final chResults = widget.challengeId == null
        ? const <GameResult>[]
        : [
            for (final r in ref.watch(gameResultsProvider))
              if (r.challengeId == widget.challengeId ||
                  (r.r.id == challenge?.r.id))
                r,
          ];
    final c = challenge;
    final fromResult = c == null
        ? null
        : ref
              .watch(gameResultsProvider)
              .where(
                (r) =>
                    r.gameId == c.gameId &&
                    r.memberId == c.from &&
                    r.challengeId == null &&
                    r.when.isBefore(c.when.add(const Duration(minutes: 5))),
              )
              .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSurface(
          child: Column(
            children: [
              Text('🎉', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              VoiceText(
                VoiceContext.gameFinish,
                fallback: tr(context, 'Nicely done!', '¡Bien hecho!'),
                feature: 'games',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              for (final (id, o) in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (id.isNotEmpty) ...[
                        AlterDot(id, size: 26),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          id.isEmpty
                              ? (o.summary.isEmpty
                                    ? tr(context, 'Finished', 'Terminado')
                                    : o.summary)
                              : '${names[id]}${o.summary.isEmpty ? '' : ' — ${o.summary}'}',
                        ),
                      ),
                      if (o.scored)
                        Text(
                          '${o.score}${o.max == null ? '' : ' / ${o.max}'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              if (scored.length > 1) ...[
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final best = scored.reduce(
                      (a, b) => (a.$2.score ?? 0) >= (b.$2.score ?? 0) ? a : b,
                    );
                    final tie =
                        scored
                            .where((e) => e.$2.score == best.$2.score)
                            .length >
                        1;
                    return tie
                        ? VoiceText(
                            VoiceContext.gameTie,
                            fallback: tr(
                              context,
                              'A tie — well played, everyone!',
                              '¡Empate! Bien jugado, todos.',
                            ),
                            feature: 'games',
                            style: theme.textTheme.bodySmall,
                          )
                        : VoiceText(
                            VoiceContext.gameWin,
                            fallback: tr(
                              context,
                              '${names[best.$1]} scored highest this time.',
                              '${names[best.$1]} sacó la puntuación más alta esta vez.',
                            ),
                            feature: 'games',
                            vars: {'name': names[best.$1] ?? ''},
                            style: theme.textTheme.bodySmall,
                          );
                  },
                ),
              ],
              if (fromResult != null && fromResult.score != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tr(
                      context,
                      '${names[fromResult.memberId] ?? 'The challenger'} scored ${fromResult.score}${fromResult.max == null ? '' : ' / ${fromResult.max}'} on this one.',
                      '${names[fromResult.memberId] ?? 'Quien retó'} sacó ${fromResult.score}${fromResult.max == null ? '' : ' / ${fromResult.max}'} en este reto.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (chResults.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr(
                      context,
                      '${chResults.length} alters have played this challenge.',
                      '${chResults.length} alters han jugado este reto.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              for (final (_, o) in entries)
                if (o.memorable != null && o.memorable!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '"${o.memorable}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (widget.onComplete == null) ...[
          const SizedBox(height: 14),
          PrismButton(
            tone: PrismButtonTone.filled,
            expanded: true,
            icon: PhosphorIcons.arrowCounterClockwise(),
            label: tr(context, 'Play again', 'Jugar otra vez'),
            onPressed: () {
              _seed = math.Random().nextInt(1 << 30);
              _start();
            },
          ),
          if (d.seeded && d.style == PlayStyle.turns) ...[
            const SizedBox(height: 8),
            PrismButton(
              expanded: true,
              icon: PhosphorIcons.paperPlaneTilt(),
              label: tr(
                context,
                'Challenge another alter with this one',
                'Retar a otro alter con este',
              ),
              onPressed: () => _challenge(context),
            ),
          ],
          const SizedBox(height: 8),
          PrismButton(
            expanded: true,
            icon: PhosphorIcons.notebook(),
            label: tr(context, 'Save to Journal', 'Guardar en el diario'),
            onPressed: () async {
              final lines = [
                for (final (id, o) in entries)
                  '${id.isEmpty ? '' : '${names[id]}: '}${o.summary}${o.scored ? ' (${o.score}${o.max == null ? '' : '/${o.max}'})' : ''}${o.memorable == null ? '' : '\n"${o.memorable}"'}',
              ];
              await ref
                  .read(trackerNotifierProvider.notifier)
                  .create(
                    kind: TrackerKind.journalEntry,
                    title: '${d.emoji} ${trp(context, d.name)}',
                    body: lines.join('\n'),
                    memberId: _players.isEmpty ? null : _players.first,
                    occurredAt: DateTime.now(),
                    tags: const ['games'],
                  );
              if (context.mounted)
                PrismToast.show(
                  context,
                  message: tr(
                    context,
                    'Saved to Journal',
                    'Guardado en el diario',
                  ),
                );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _challenge(BuildContext context) async {
    final to = await pickAlters(
      context,
      ref,
      title: tr(
        context,
        'Who should take the challenge?',
        '¿Quién acepta el reto?',
      ),
    );
    if (to == null || to.isEmpty || !context.mounted) return;
    await ref
        .read(gamesActionsProvider)
        .createChallenge(
          gameId: widget.gameId,
          from: _players.isEmpty ? null : _players.first,
          to: to,
          seed: _seed,
        );
    if (context.mounted)
      PrismToast.show(
        context,
        message: tr(
          context,
          'Challenge left for them — they can play whenever they like.',
          'Reto enviado: pueden jugarlo cuando quieran.',
        ),
      );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
