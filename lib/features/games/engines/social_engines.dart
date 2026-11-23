import 'dart:math' as math;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/core/games_data.dart';
import 'package:prism_plurality/features/games/engines/canvas_kit.dart';
import 'package:prism_plurality/features/games/engines/word_engines.dart' show Chip2;
import 'package:prism_plurality/shared/ui_kit.dart';

/// "Pass the device to …" screen used inside together-games.
class PassScreen extends StatelessWidget {
  const PassScreen({super.key, required this.name, required this.onReady, this.note});
  final String name;
  final VoidCallback onReady;
  final String? note;
  @override
  Widget build(BuildContext context) => GamePanel(
    child: Column(
      children: [
        Icon(PhosphorIcons.handHeart(), size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        GamePrompt(name.isEmpty ? tr(context, 'Next player', 'Siguiente jugador') : tr(context, 'Over to $name', 'Turno de $name')),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(note!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
        GameActions(
          children: [PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'I\'m ready', 'Estoy listo'), onPressed: onReady)],
        ),
      ],
    ),
  );
}

List<String?> _playersOf(GameSession s, {int min = 2}) {
  final p = <String?>[...s.players];
  while (p.length < min) {
    p.add(null);
  }
  return p;
}

String _label(BuildContext context, GameSession s, String? id, int index) => id == null ? tr(context, 'Player ${index + 1}', 'Jugador ${index + 1}') : s.nameOf(id);

// ---------------------------------------------------------------------------
// Two Truths and a Lie
// ---------------------------------------------------------------------------

class TwoTruthsGame extends StatefulWidget {
  const TwoTruthsGame({super.key, required this.session});
  final GameSession session;
  @override
  State<TwoTruthsGame> createState() => _TwoTruthsGameState();
}

class _TwoTruthsGameState extends State<TwoTruthsGame> {
  late final List<String?> _players = _playersOf(widget.session);
  int _teller = 0;
  int _stage = 0; // 0 write, 1 pass to guessers, 2 guessing, 3 reveal
  final _ctl = [TextEditingController(), TextEditingController(), TextEditingController()];
  int _lie = 2;
  late List<int> _order;
  final Map<int, int> _guesses = {}; // guesser index -> picked statement
  int _guesser = 0;
  final Map<int, int> _points = {};
  final List<String> _log = [];

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  List<int> get _guessers => [
    for (var i = 0; i < _players.length; i++)
      if (i != _teller) i,
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final teller = _label(context, s, _players[_teller], _teller);
    switch (_stage) {
      case 0:
        return GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(tr(context, '$teller, write two true things and one invented one', '$teller, escribe dos verdades y una invención'), size: 17),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'Only share what you\'re comfortable sharing. Tap the circle to mark the invented one.',
                  'Comparte solo lo que te resulte cómodo. Toca el círculo para marcar la invención.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      PrismIconButton(
                        icon: _lie == i ? PhosphorIcons.maskHappy(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                        tooltip: tr(context, 'Mark as the invented one', 'Marcar como invención'),
                        color: _lie == i ? Theme.of(context).colorScheme.primary : null,
                        onPressed: () => setState(() => _lie = i),
                      ),
                      Expanded(
                        child: PrismTextField(controller: _ctl[i], hintText: tr(context, 'Statement ${i + 1}', 'Frase ${i + 1}'), onChanged: (_) => setState(() {})),
                      ),
                    ],
                  ),
                ),
              GameActions(
                children: [
                  PrismButton(
                    tone: PrismButtonTone.filled,
                    label: tr(context, 'Done — hide my answers', 'Listo: ocultar respuestas'),
                    onPressed: _ctl.every((c) => c.text.trim().isNotEmpty)
                        ? () => setState(() {
                            _order = shuffled([0, 1, 2], s.rng(80 + _teller));
                            _guesses.clear();
                            _guesser = 0;
                            _stage = 1;
                          })
                        : () {},
                  ),
                ],
              ),
            ],
          ),
        );
      case 1:
        final g = _guessers[_guesser];
        return PassScreen(
          name: _label(context, s, _players[g], g),
          note: tr(context, 'Guess which of $teller\'s statements is invented.', 'Adivina cuál de las frases de $teller es inventada.'),
          onReady: () => setState(() => _stage = 2),
        );
      case 2:
        final g = _guessers[_guesser];
        return GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(tr(context, '${_label(context, s, _players[g], g)}: which one is invented?', '${_label(context, s, _players[g], g)}: ¿cuál es inventada?'), size: 17),
              const SizedBox(height: 10),
              for (final i in _order)
                OptionTile(
                  label: _ctl[i].text.trim(),
                  onTap: () => setState(() {
                    _guesses[g] = i;
                    if (_guesser + 1 < _guessers.length) {
                      _guesser++;
                      _stage = 1;
                    } else {
                      _stage = 3;
                      for (final e in _guesses.entries) {
                        if (e.value == _lie) _points[e.key] = (_points[e.key] ?? 0) + 1;
                      }
                      if (_guesses.values.any((v) => v != _lie)) _points[_teller] = (_points[_teller] ?? 0) + _guesses.values.where((v) => v != _lie).length;
                      _log.add('$teller: ${_ctl[_lie].text.trim()}');
                    }
                  }),
                ),
            ],
          ),
        );
      default:
        return GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(tr(context, 'The invented one was…', 'La invención era…'), size: 16),
              const SizedBox(height: 8),
              for (var i = 0; i < 3; i++) OptionTile(label: _ctl[i].text.trim(), state: i == _lie ? false : true, onTap: null),
              const SizedBox(height: 8),
              for (final e in _guesses.entries)
                Text('${_label(context, s, _players[e.key], e.key)}: ${e.value == _lie ? tr(context, '✓ spotted it', '✓ acertó') : tr(context, 'fooled!', '¡engañado!')}', textAlign: TextAlign.center),
              GameActions(
                children: [
                  if (_teller + 1 < _players.length)
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Next teller', 'Siguiente'),
                      onPressed: () => setState(() {
                        _teller++;
                        for (final c in _ctl) {
                          c.clear();
                        }
                        _lie = 2;
                        _stage = 0;
                      }),
                    ),
                  PrismButton(
                    tone: _teller + 1 < _players.length ? PrismButtonTone.subtle : PrismButtonTone.filled,
                    label: tr(context, 'Finish', 'Terminar'),
                    onPressed: () {
                      final board = [for (var i = 0; i < _players.length; i++) '${_label(context, s, _players[i], i)} ${_points[i] ?? 0}'].join(' · ');
                      s.finish(GameOutcome(summary: board, memorable: _log.isEmpty ? null : _log.last));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Guess the Alter (clues each alter chose to share)
// ---------------------------------------------------------------------------

class GuessAlterGame extends ConsumerStatefulWidget {
  const GuessAlterGame({super.key, required this.session});
  final GameSession session;
  @override
  ConsumerState<GuessAlterGame> createState() => _GuessAlterGameState();
}

class _GuessAlterGameState extends ConsumerState<GuessAlterGame> {
  late final math.Random _rng = widget.session.rng(81);
  List<(String, String)>? _rounds; // (memberId, clue)
  int _i = 0, _score = 0;
  int _shown = 1;
  String? _picked;
  late List<String> _options;
  final _clueCtl = TextEditingController();

  @override
  void dispose() {
    _clueCtl.dispose();
    super.dispose();
  }

  void _build() {
    final profiles = ref.read(gameProfilesProvider);
    final names = ref.read(gameNamesProvider);
    final byMember = <String, List<String>>{
      for (final e in profiles.entries)
        if (e.key.isNotEmpty && e.value.clues.isNotEmpty && names.containsKey(e.key)) e.key: e.value.clues,
    };
    final ids = shuffled(byMember.keys, _rng).take(8).toList();
    _rounds = [for (final id in ids) (id, byMember[id]!.join('\n'))];
    _setOptions();
  }

  void _setOptions() {
    if (_rounds!.isEmpty) return;
    final names = ref.read(gameNamesProvider);
    final answer = _rounds![_i].$1;
    final others = shuffled(names.keys.where((k) => k != answer), _rng).take(3);
    _options = shuffled([answer, ...others], _rng);
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(gameNamesProvider);
    if (_rounds == null) _build();
    final me = widget.session.player;
    if (_rounds!.length < 2 || names.length < 2) {
      final myClues = me == null ? const <String>[] : (ref.watch(gameProfilesProvider)[me]?.clues ?? const <String>[]);
      return GamePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GamePrompt(tr(context, 'Not enough shared clues yet', 'Aún no hay suficientes pistas'), size: 17),
            const SizedBox(height: 6),
            Text(
              tr(
                context,
                'This game only uses clues alters choose to share. At least two alters need clues. You can add yours here — they\'re kept in your Games profile and you can remove them any time.',
                'Este juego solo usa pistas que cada alter decide compartir. Al menos dos alters necesitan pistas. Puedes añadir las tuyas aquí; se guardan en tu perfil de juegos y puedes quitarlas cuando quieras.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (me != null) ...[
              const SizedBox(height: 10),
              for (final c in myClues) Chip2('• $c'),
              Row(
                children: [
                  Expanded(
                    child: PrismTextField(controller: _clueCtl, hintText: tr(context, 'e.g. "I love thunderstorms"', 'p. ej. "Me encantan las tormentas"')),
                  ),
                  PrismIconButton(
                    icon: PhosphorIcons.plus(),
                    tooltip: tr(context, 'Add clue', 'Añadir pista'),
                    onPressed: () async {
                      final t = _clueCtl.text.trim();
                      if (t.isEmpty) return;
                      await ref.read(gamesActionsProvider).setClues(me, [...myClues, t]);
                      _clueCtl.clear();
                      setState(() => _rounds = null);
                    },
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(tr(context, 'Choose an alter in setup to add clues.', 'Elige un alter en la preparación para añadir pistas.'), textAlign: TextAlign.center),
              ),
          ],
        ),
      );
    }
    final (answer, clues) = _rounds![_i];
    final lines = clues.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _i + 1, total: _rounds!.length, trailing: '★ $_score'),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(tr(context, 'Who shared these clues?', '¿Quién compartió estas pistas?'), size: 17),
              const SizedBox(height: 8),
              for (final l in lines.take(_shown))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '“$l”',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              if (_shown < lines.length && _picked == null)
                Center(
                  child: PrismButton(density: PrismControlDensity.compact, label: tr(context, 'Another clue', 'Otra pista'), onPressed: () => setState(() => _shown++)),
                ),
              const SizedBox(height: 8),
              for (final o in _options)
                OptionTile(
                  leading: AlterDot(o, size: 24),
                  label: names[o] ?? '',
                  state: _picked == null ? null : (o == answer ? true : (o == _picked ? false : null)),
                  onTap: _picked != null
                      ? null
                      : () => setState(() {
                          _picked = o;
                          if (o == answer) _score++;
                        }),
                ),
              if (_picked != null)
                GameActions(
                  children: [
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Next', 'Siguiente'),
                      onPressed: () {
                        if (_i + 1 >= _rounds!.length) {
                          widget.session.finish(GameOutcome(score: _score, max: _rounds!.length, summary: '$_score / ${_rounds!.length}'));
                        } else {
                          setState(() {
                            _i++;
                            _picked = null;
                            _shown = 1;
                            _setOptions();
                          });
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Who Knows Me Best? · Guess the Favorite
// ---------------------------------------------------------------------------

class KnowMeGame extends StatefulWidget {
  const KnowMeGame({super.key, required this.session, required this.questions, this.count = 5});
  final GameSession session;
  final List<String> questions;
  final int count;
  @override
  State<KnowMeGame> createState() => _KnowMeGameState();
}

class _KnowMeGameState extends State<KnowMeGame> {
  late final List<String?> _players = _playersOf(widget.session);
  late final List<String> _qs = shuffled(widget.questions, widget.session.rng(82)).take(widget.count).toList();
  int _stage = 0; // 0 subject answers, 1 pass, 2 guesser answers, 3 mark
  late final List<TextEditingController> _ctl = [for (final _ in _qs) TextEditingController()];
  late List<String> _truth;
  final Map<int, List<String>> _guesses = {};
  final Map<int, Set<int>> _right = {};
  int _g = 1;

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _form(String title, VoidCallback onDone) => GamePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GamePrompt(title, size: 17),
        const SizedBox(height: 10),
        for (var i = 0; i < _qs.length; i++) ...[
          Text(_qs[i], style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          PrismTextField(controller: _ctl[i], hintText: tr(context, 'Answer (or skip)', 'Respuesta (o salta)')),
          const SizedBox(height: 10),
        ],
        GameActions(
          children: [PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Done', 'Hecho'), onPressed: onDone)],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final subject = _label(context, s, _players[0], 0);
    switch (_stage) {
      case 0:
        return _form(
          tr(context, '$subject, answer about yourself (hidden from others)', '$subject, responde sobre ti (oculto)'),
          () => setState(() {
            _truth = [for (final c in _ctl) c.text.trim()];
            for (final c in _ctl) {
              c.clear();
            }
            _stage = 1;
          }),
        );
      case 1:
        return PassScreen(name: _label(context, s, _players[_g], _g), note: tr(context, 'Guess how $subject answered.', 'Adivina qué respondió $subject.'), onReady: () => setState(() => _stage = 2));
      case 2:
        return _form(
          tr(context, 'How did $subject answer?', '¿Qué respondió $subject?'),
          () => setState(() {
            _guesses[_g] = [for (final c in _ctl) c.text.trim()];
            for (final c in _ctl) {
              c.clear();
            }
            if (_g + 1 < _players.length) {
              _g++;
              _stage = 1;
            } else {
              _stage = 3;
            }
          }),
        );
      default:
        return GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(tr(context, '$subject, tap the guesses that are right', '$subject, toca las respuestas acertadas'), size: 16),
              const SizedBox(height: 10),
              for (var i = 0; i < _qs.length; i++) ...[
                Text(_qs[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${tr(context, 'Answer', 'Respuesta')}: ${_truth[i].isEmpty ? '—' : _truth[i]}'),
                for (final e in _guesses.entries)
                  OptionTile(
                    label: '${_label(context, s, _players[e.key], e.key)}: ${e.value[i].isEmpty ? '—' : e.value[i]}',
                    state: (_right[e.key] ?? {}).contains(i) ? true : null,
                    onTap: () => setState(() {
                      final set = _right.putIfAbsent(e.key, () => {});
                      set.contains(i) ? set.remove(i) : set.add(i);
                    }),
                  ),
                const SizedBox(height: 8),
              ],
              GameActions(
                children: [
                  PrismButton(
                    tone: PrismButtonTone.filled,
                    label: tr(context, 'Finish', 'Terminar'),
                    onPressed: () {
                      final board = [for (final g in _guesses.keys) '${_label(context, s, _players[g], g)} ${(_right[g] ?? {}).length}/${_qs.length}'].join(' · ');
                      final best = _guesses.keys.isEmpty ? 0 : _guesses.keys.map((g) => (_right[g] ?? {}).length).reduce(math.max);
                      s.finish(GameOutcome(score: best, max: _qs.length, summary: board));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Guess the Drawing
// ---------------------------------------------------------------------------

class GuessDrawingGame extends StatefulWidget {
  const GuessDrawingGame({super.key, required this.session, required this.prompts});
  final GameSession session;
  final List<String> prompts;
  @override
  State<GuessDrawingGame> createState() => _GuessDrawingGameState();
}

class _GuessDrawingGameState extends State<GuessDrawingGame> {
  late final math.Random _rng = widget.session.rng(83);
  late final List<String?> _players = _playersOf(widget.session);
  int _drawer = 0, _stage = 0; // 0 draw, 1 pass, 2 guess, 3 reveal
  late String _word;
  late List<String> _options;
  DrawingController _c = DrawingController();
  String? _picked;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _newWord();
  }

  void _newWord() {
    final pool = shuffled(widget.prompts, _rng);
    _word = pool.first;
    _options = shuffled(pool.take(4), _rng);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final drawer = _label(context, s, _players[_drawer], _drawer);
    final guesser = (_drawer + 1) % _players.length;
    switch (_stage) {
      case 0:
        return GamePanel(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(tr(context, '$drawer, draw: $_word', '$drawer, dibuja: $_word'), size: 17),
              Text(
                tr(context, 'No letters or numbers! Stick figures are perfect.', '¡Sin letras ni números! Los monigotes son perfectos.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              DrawingBoard(controller: _c),
              DrawingToolbar(controller: _c),
              GameActions(
                children: [
                  PrismButton(label: tr(context, 'Different word', 'Otra palabra'), onPressed: () => setState(_newWord)),
                  PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Done drawing', 'Terminé'), onPressed: () => setState(() => _stage = 1)),
                ],
              ),
            ],
          ),
        );
      case 1:
        return PassScreen(
          name: _label(context, s, _players[guesser], guesser),
          note: tr(context, 'Guess what $drawer drew.', 'Adivina qué dibujó $drawer.'),
          onReady: () => setState(() => _stage = 2),
        );
      default:
        return GamePanel(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IgnorePointer(child: DrawingBoard(controller: _c)),
              const SizedBox(height: 8),
              for (final o in _options)
                OptionTile(
                  label: o,
                  state: _picked == null ? null : (o == _word ? true : (o == _picked ? false : null)),
                  onTap: _picked != null
                      ? null
                      : () => setState(() {
                          _picked = o;
                          if (o == _word) _correct++;
                        }),
                ),
              if (_picked != null)
                GameActions(
                  children: [
                    PrismButton(
                      label: tr(context, 'Swap and draw again', 'Cambiar y dibujar'),
                      onPressed: () => setState(() {
                        _drawer = (_drawer + 1) % _players.length;
                        _c.dispose();
                        _c = DrawingController();
                        _picked = null;
                        _stage = 0;
                        _newWord();
                      }),
                    ),
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Finish', 'Terminar'),
                      onPressed: () => s.finish(GameOutcome(score: _correct, summary: tr(context, '$_correct drawings guessed', '$_correct dibujos adivinados'))),
                    ),
                  ],
                ),
            ],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Shared text projects: Story Chain · Collaborative Poetry · Worldbuilder ·
// Word Association. Lines are attributed and the project saves as it goes,
// so alters can add to it on different days.
// ---------------------------------------------------------------------------

class SharedTextGame extends StatefulWidget {
  const SharedTextGame({super.key, required this.session, required this.starters, this.sections, this.hideEarlier = false, this.oneWord = false, this.hint});
  final GameSession session;
  final List<String> starters;

  /// Worldbuilder: named sections (Name, Places, Peoples…).
  final List<String>? sections;

  /// Story chain option: only the last line is visible while writing.
  final bool hideEarlier;
  final bool oneWord;
  final String? hint;
  @override
  State<SharedTextGame> createState() => _SharedTextGameState();
}

class _SharedTextGameState extends State<SharedTextGame> {
  late final List<Map<String, Object?>> _lines = [for (final m in (widget.session.saved?['lines'] as List?) ?? const []) (m as Map).cast<String, Object?>()];
  late String _starter = widget.session.saved?['starter'] as String? ?? widget.starters[widget.session.rng(84).nextInt(widget.starters.length)];
  late int _turn = (widget.session.saved?['turn'] as num?)?.toInt() ?? 0;
  late bool _hide = widget.hideEarlier;
  late String? _section = widget.sections?.first;
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<String?> get _players => widget.session.players.isEmpty ? [null] : widget.session.players;
  String? get _who => _players[_turn % _players.length];

  void _save() => widget.session.save({'lines': _lines, 'starter': _starter, 'turn': _turn});

  void _add() {
    var t = _ctl.text.trim();
    if (t.isEmpty) return;
    if (widget.oneWord) t = t.split(RegExp(r'\s+')).first;
    setState(() {
      _lines.add({'t': t, if (_who != null) 'a': _who, if (_section != null) 's': _section});
      _turn++;
      _ctl.clear();
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    Widget line(Map<String, Object?> l) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (l['a'] != null) Padding(padding: const EdgeInsets.only(right: 6, top: 2), child: AlterDot('${l['a']}', size: 18)),
          Expanded(child: Text('${l['t']}', style: const TextStyle(height: 1.4))),
        ],
      ),
    );
    final visible = _hide && _lines.length > 1 ? [_lines.last] : _lines;
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _starter,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          if (_lines.isEmpty && widget.starters.length > 1)
            Center(
              child: PrismButton(
                density: PrismControlDensity.compact,
                label: tr(context, 'Different starter', 'Otro inicio'),
                onPressed: () => setState(() => _starter = widget.starters[math.Random().nextInt(widget.starters.length)]),
              ),
            ),
          const Divider(height: 18),
          if (widget.sections != null)
            for (final sec in widget.sections!) ...[
              Text(sec, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              for (final l in _lines.where((l) => l['s'] == sec)) line(l),
              const SizedBox(height: 6),
            ]
          else ...[
            if (_hide && _lines.length > 1) Text(tr(context, '(${_lines.length - 1} earlier lines hidden)', '(${_lines.length - 1} líneas ocultas)'), style: theme.textTheme.bodySmall),
            for (final l in visible) line(l),
          ],
          const SizedBox(height: 10),
          Text(_who == null ? tr(context, 'Your turn', 'Tu turno') : tr(context, '${s.nameOf(_who)}\'s turn', 'Turno de ${s.nameOf(_who)}'), style: theme.textTheme.titleSmall),
          if (widget.sections != null)
            Wrap(
              spacing: 6,
              children: [for (final sec in widget.sections!) PrismChip(label: sec, selected: _section == sec, onTap: () => setState(() => _section = sec))],
            ),
          const SizedBox(height: 6),
          PrismTextField(
            controller: _ctl,
            maxLines: widget.oneWord ? 1 : 3,
            hintText: widget.hint ?? (widget.oneWord ? tr(context, 'One related word', 'Una palabra relacionada') : tr(context, 'Add the next line', 'Añade la siguiente línea')),
            onSubmitted: (_) => _add(),
          ),
          GameActions(
            children: [
              PrismButton(label: tr(context, 'Add', 'Añadir'), icon: PhosphorIcons.plus(), onPressed: _add),
              if (widget.hideEarlier)
                PrismButton(label: _hide ? tr(context, 'Show all', 'Mostrar todo') : tr(context, 'Hide earlier', 'Ocultar anteriores'), onPressed: () => setState(() => _hide = !_hide)),
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Finish', 'Terminar'),
                onPressed: () {
                  final text = [_starter, ..._lines.map((l) => '${l['t']}')].join(widget.oneWord ? ' → ' : '\n');
                  s.finish(GameOutcome(summary: tr(context, '${_lines.length} contributions', '${_lines.length} aportaciones'), memorable: text, details: {'lines': _lines}));
                },
              ),
            ],
          ),
          Text(tr(context, 'Progress saves automatically — come back any time.', 'Se guarda automáticamente: vuelve cuando quieras.'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
