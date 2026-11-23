import 'dart:async';
import 'dart:math' as math;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/engines/grid_engines.dart' show CellGrid;
import 'package:prism_plurality/features/games/engines/tone_player.dart';
import 'package:prism_plurality/features/games/engines/word_engines.dart' show Chip2;
import 'package:prism_plurality/shared/ui_kit.dart';

// ---------------------------------------------------------------------------
// Match pairs (synonyms, antonyms, languages, notes, flashcards)
// ---------------------------------------------------------------------------

class MatchPairsGame extends StatefulWidget {
  const MatchPairsGame({super.key, required this.session, required this.pairs, this.perRound = 5, this.rounds = 3, this.leftLabel, this.rightLabel});
  final GameSession session;
  final List<(String, String)> pairs;
  final int perRound;
  final int rounds;
  final String? leftLabel;
  final String? rightLabel;
  @override
  State<MatchPairsGame> createState() => _MatchPairsGameState();
}

class _MatchPairsGameState extends State<MatchPairsGame> {
  late final math.Random _rng = widget.session.rng(60);
  late final List<(String, String)> _all = shuffled(widget.pairs, _rng);
  int _round = 0, _score = 0, _mistakes = 0;
  late List<(String, String)> _set;
  late List<String> _right;
  final Set<int> _done = {};
  int? _leftSel;
  int? _wrongFlash;

  int get _rounds => math.min(widget.rounds, (_all.length / widget.perRound).ceil());

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    _set = _all.skip(_round * widget.perRound).take(widget.perRound).toList();
    _right = shuffled(_set.map((p) => p.$2), _rng);
    _done.clear();
    _leftSel = null;
  }

  void _pickRight(int j) {
    final i = _leftSel;
    if (i == null) return;
    if (_set[i].$2 == _right[j]) {
      setState(() {
        _done.add(i);
        _leftSel = null;
        _score++;
      });
      if (_done.length == _set.length) {
        if (_round + 1 >= _rounds) {
          widget.session.finish(GameOutcome(score: _score, max: _score + _mistakes, summary: tr(context, '$_score matches, $_mistakes slips', '$_score parejas, $_mistakes fallos')));
        } else {
          setState(() {
            _round++;
            _deal();
          });
        }
      }
    } else {
      setState(() {
        _mistakes++;
        _wrongFlash = j;
      });
      Future.delayed(const Duration(milliseconds: 500), () => mounted ? setState(() => _wrongFlash = null) : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneRight = {for (final i in _done) _set[i].$2};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _round + 1, total: _rounds, trailing: '★ $_score'),
        GamePanel(
          child: Column(
            children: [
              Text(
                tr(context, 'Tap a word on the left, then its match on the right.', 'Toca una palabra a la izquierda y luego su pareja a la derecha.'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (widget.leftLabel != null) Text(widget.leftLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
                        for (var i = 0; i < _set.length; i++)
                          OptionTile(label: _set[i].$1, selected: _leftSel == i, state: _done.contains(i) ? true : null, onTap: _done.contains(i) ? null : () => setState(() => _leftSel = i)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        if (widget.rightLabel != null) Text(widget.rightLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
                        for (var j = 0; j < _right.length; j++)
                          OptionTile(
                            label: _right[j],
                            state: doneRight.contains(_right[j]) ? true : (_wrongFlash == j ? false : null),
                            onTap: doneRight.contains(_right[j]) ? null : () => _pickRight(j),
                          ),
                      ],
                    ),
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
// Put in order (timeline, sentences, origami, shapes)
// ---------------------------------------------------------------------------

class OrderingGame extends StatefulWidget {
  const OrderingGame({super.key, required this.session, required this.sets, required this.prompt, this.rounds = 3, this.reveal});
  final GameSession session;

  /// Each set in the correct order; title shown above.
  final List<(String, List<String>)> sets;
  final String prompt;
  final int rounds;

  /// Optional extra shown after checking (e.g. years).
  final String Function(String item)? reveal;
  @override
  State<OrderingGame> createState() => _OrderingGameState();
}

class _OrderingGameState extends State<OrderingGame> {
  late final math.Random _rng = widget.session.rng(61);
  late final List<(String, List<String>)> _sets = shuffled(widget.sets, _rng).take(widget.rounds).toList();
  int _i = 0, _score = 0;
  late List<String> _pool;
  final List<String> _placed = [];
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _pool = shuffled(_sets[0].$2, _rng);
  }

  @override
  Widget build(BuildContext context) {
    final (title, correct) = _sets[_i];
    final right = _checked && List.generate(correct.length, (k) => k < _placed.length && _placed[k] == correct[k]).every((x) => x);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _i + 1, total: _sets.length, trailing: '★ $_score'),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              Text(widget.prompt, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              for (var k = 0; k < _placed.length; k++)
                OptionTile(
                  leading: Text('${k + 1}.', style: const TextStyle(fontWeight: FontWeight.w800)),
                  label: '${_placed[k]}${_checked && widget.reveal != null ? ' — ${widget.reveal!(_placed[k])}' : ''}',
                  state: _checked ? _placed[k] == correct[k] : null,
                  onTap: _checked ? null : () => setState(() => _pool.add(_placed.removeAt(k))),
                ),
              if (_pool.isNotEmpty) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _pool)
                      PrismChip(
                        label: p,
                        selected: false,
                        onTap: () => setState(() {
                          _pool.remove(p);
                          _placed.add(p);
                        }),
                      ),
                  ],
                ),
              ],
              GameActions(
                children: [
                  if (!_checked && _pool.isEmpty)
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Check', 'Comprobar'),
                      onPressed: () => setState(() {
                        _checked = true;
                        if (List.generate(correct.length, (k) => _placed[k] == correct[k]).every((x) => x)) _score++;
                      }),
                    ),
                  if (_checked) ...[
                    Text(right ? tr(context, '✓ Perfect order!', '✓ ¡Orden perfecto!') : tr(context, 'Close! Correct order: ${correct.join(' → ')}', '¡Casi! Orden correcto: ${correct.join(' → ')}')),
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Next', 'Siguiente'),
                      onPressed: () {
                        if (_i + 1 >= _sets.length) {
                          widget.session.finish(GameOutcome(score: _score, max: _sets.length, summary: '$_score / ${_sets.length}'));
                        } else {
                          setState(() {
                            _i++;
                            _placed.clear();
                            _pool = shuffled(_sets[_i].$2, _rng);
                            _checked = false;
                          });
                        }
                      },
                    ),
                  ],
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
// Prompt decks: Would You Rather, This or That, Never Have I Ever, Cozy
// Truth or Dare, Conversation Roulette, question cards, drawing prompts…
// ---------------------------------------------------------------------------

enum DeckMode {
  /// Two choices; each player picks; answers are kept.
  choice,

  /// A prompt to talk or write about; optional written answers.
  prompt,

  /// "I have" / "I haven't".
  haveNot,

  /// Pick truth or dare, then get one.
  truthDare,
}

class PromptDeckGame extends StatefulWidget {
  const PromptDeckGame({
    super.key,
    required this.session,
    required this.mode,
    this.prompts = const [],
    this.choices = const [],
    this.dares = const [],
    this.writeAnswers = false,
    this.count = 10,
    this.choiceLabel,
  });
  final GameSession session;
  final DeckMode mode;
  final List<String> prompts;
  final List<(String, String)> choices;
  final List<String> dares;
  final bool writeAnswers;
  final int count;

  /// E.g. "Would you rather…"
  final String? choiceLabel;
  @override
  State<PromptDeckGame> createState() => _PromptDeckGameState();
}

class _PromptDeckGameState extends State<PromptDeckGame> {
  late final math.Random _rng = widget.session.rng(62);
  late final List<int> _order = shuffled(List.generate(widget.mode == DeckMode.choice ? widget.choices.length : widget.prompts.length, (i) => i), _rng);
  int _i = 0;
  final Map<String, String> _answers = {}; // player -> answer for current card
  final List<String> _log = [];
  final _ctl = TextEditingController();
  String? _tdChoice;
  int _tdPick = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<String?> get _players => widget.session.players.isEmpty ? [null] : widget.session.players;
  String? get _whoNext => _players.where((p) => !_answers.containsKey(p ?? '')).firstOrNull;
  bool get _allAnswered => _players.every((p) => _answers.containsKey(p ?? ''));

  void _answer(String a) {
    final who = _whoNext;
    setState(() => _answers[who ?? ''] = a);
  }

  void _next() {
    final card = _cardText();
    if (_answers.isNotEmpty) {
      _log.add('$card — ${[for (final e in _answers.entries) '${e.key.isEmpty ? '' : '${widget.session.nameOf(e.key)}: '}${e.value}'].join('; ')}');
    }
    if (_i + 1 >= math.min(widget.count, _order.length)) {
      widget.session.finish(
        GameOutcome(summary: tr(context, '${_i + 1} cards together', '${_i + 1} cartas juntos'), memorable: _log.isEmpty ? null : _log[_rng.nextInt(_log.length)], details: {'log': _log}),
      );
      return;
    }
    setState(() {
      _i++;
      _answers.clear();
      _ctl.clear();
      _tdChoice = null;
      _tdPick = _rng.nextInt(1000);
    });
  }

  String _cardText() => switch (widget.mode) {
    DeckMode.choice => '${widget.choices[_order[_i]].$1} / ${widget.choices[_order[_i]].$2}',
    DeckMode.truthDare => _tdChoice == 'dare' ? widget.dares[_tdPick % widget.dares.length] : widget.prompts[_order[_i]],
    _ => widget.prompts[_order[_i]],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final who = _whoNext;
    final total = math.min(widget.count, _order.length);
    Widget answerArea;
    switch (widget.mode) {
      case DeckMode.choice:
        final (a, b) = widget.choices[_order[_i]];
        answerArea = Column(
          children: [
            if (widget.choiceLabel != null) Text(widget.choiceLabel!, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            OptionTile(label: a, onTap: _allAnswered ? null : () => _answer(a)),
            Text(tr(context, 'or', 'o'), style: theme.textTheme.labelMedium),
            OptionTile(label: b, onTap: _allAnswered ? null : () => _answer(b)),
          ],
        );
      case DeckMode.haveNot:
        answerArea = Column(
          children: [
            GamePrompt(widget.prompts[_order[_i]], size: 18),
            const SizedBox(height: 10),
            OptionTile(label: tr(context, '🙋 I have', '🙋 Yo sí'), onTap: _allAnswered ? null : () => _answer(tr(context, 'I have', 'Yo sí'))),
            OptionTile(label: tr(context, '🙅 I haven\'t', '🙅 Yo no'), onTap: _allAnswered ? null : () => _answer(tr(context, 'I haven\'t', 'Yo no'))),
          ],
        );
      case DeckMode.truthDare:
        answerArea = _tdChoice == null
            ? Column(
                children: [
                  GamePrompt(tr(context, 'Truth or dare?', '¿Verdad o reto?')),
                  const SizedBox(height: 10),
                  OptionTile(label: tr(context, '💬 Truth', '💬 Verdad'), onTap: () => setState(() => _tdChoice = 'truth')),
                  OptionTile(label: tr(context, '✨ Dare (gentle)', '✨ Reto (suave)'), onTap: () => setState(() => _tdChoice = 'dare')),
                  const SizedBox(height: 6),
                  Text(tr(context, 'Everything is optional — skip anything you like.', 'Todo es opcional: salta lo que quieras.'), style: theme.textTheme.bodySmall),
                ],
              )
            : Column(
                children: [
                  GamePrompt(_cardText(), size: 18),
                  const SizedBox(height: 10),
                  if (!_allAnswered) ...[
                    PrismTextField(controller: _ctl, hintText: tr(context, 'Answer or note (optional)', 'Respuesta o nota (opcional)'), maxLines: 2),
                    GameActions(
                      children: [PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Done', 'Hecho'), onPressed: () => _answer(_ctl.text.trim().isEmpty ? '✓' : _ctl.text.trim()))],
                    ),
                  ],
                ],
              );
      case DeckMode.prompt:
        answerArea = Column(
          children: [
            GamePrompt(widget.prompts[_order[_i]], size: 18),
            const SizedBox(height: 10),
            if (widget.writeAnswers && !_allAnswered) ...[
              PrismTextField(controller: _ctl, hintText: tr(context, 'Write an answer (optional)', 'Escribe una respuesta (opcional)'), maxLines: 3),
              GameActions(
                children: [
                  PrismButton(
                    tone: PrismButtonTone.filled,
                    label: tr(context, 'Save answer', 'Guardar respuesta'),
                    onPressed: () {
                      _answer(_ctl.text.trim().isEmpty ? '—' : _ctl.text.trim());
                      _ctl.clear();
                    },
                  ),
                ],
              ),
            ],
          ],
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _i + 1, total: total),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (who != null && !_allAnswered && (widget.mode != DeckMode.prompt || widget.writeAnswers))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tr(context, '${widget.session.nameOf(who)}\'s turn', 'Turno de ${widget.session.nameOf(who)}'), textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
                ),
              answerArea,
              if (_answers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [for (final e in _answers.entries) Chip2('${e.key.isEmpty ? '' : '${widget.session.nameOf(e.key)}: '}${e.value}')],
                ),
              ],
              GameActions(
                children: [
                  if (widget.mode == DeckMode.prompt && !widget.writeAnswers || _allAnswered || widget.mode == DeckMode.truthDare && _tdChoice != null)
                    PrismButton(
                      tone: _allAnswered || !widget.writeAnswers ? PrismButtonTone.filled : PrismButtonTone.subtle,
                      label: _i + 1 >= total ? tr(context, 'Finish', 'Terminar') : tr(context, 'Next card', 'Siguiente carta'),
                      onPressed: _next,
                    ),
                  if (!_allAnswered && widget.mode != DeckMode.prompt) PrismButton(label: tr(context, 'Skip', 'Saltar'), onPressed: _next),
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
// Bingo (Friendship Bingo, custom boards)
// ---------------------------------------------------------------------------

class BingoGame extends StatefulWidget {
  const BingoGame({super.key, required this.session, required this.squares});
  final GameSession session;
  final List<String> squares;
  @override
  State<BingoGame> createState() => _BingoGameState();
}

class _BingoGameState extends State<BingoGame> {
  late final List<String> _board = shuffled(widget.squares, widget.session.rng(63)).take(25).toList();
  late final Set<int> _marked = {
    for (final v in (widget.session.saved?['marked'] as List?) ?? const [12]) (v as num).toInt(),
  };

  bool get _bingo {
    for (var k = 0; k < 5; k++) {
      if (List.generate(5, (j) => _marked.contains(k * 5 + j)).every((x) => x)) return true;
      if (List.generate(5, (j) => _marked.contains(j * 5 + k)).every((x) => x)) return true;
    }
    return List.generate(5, (j) => _marked.contains(j * 6)).every((x) => x) || List.generate(5, (j) => _marked.contains(j * 4 + 4)).every((x) => x);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(
            tr(context, 'Mark squares as you do them — over days if you like. Progress is saved.', 'Marca las casillas al hacerlas, aunque sea durante días. Se guarda el progreso.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          CellGrid(
            rows: 5,
            cols: 5,
            gap: 4,
            cell: (r, c) {
              final i = r * 5 + c;
              final free = i == 12;
              final on = _marked.contains(i);
              return Semantics(
                button: true,
                selected: on,
                label: free ? 'Free' : _board[i],
                child: GestureDetector(
                  onTap: free
                      ? null
                      : () {
                          setState(() => on ? _marked.remove(i) : _marked.add(i));
                          widget.session.save({'marked': _marked.toList()});
                          if (_bingo && !on) PrismToast.show(context, message: tr(context, 'Bingo! 🎉', '¡Bingo! 🎉'));
                        },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? scheme.primary.withValues(alpha: 0.25) : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: on ? scheme.primary : scheme.outlineVariant),
                    ),
                    child: Text(free ? '⭐' : _board[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, height: 1.1), maxLines: 4, overflow: TextOverflow.ellipsis),
                  ),
                ),
              );
            },
          ),
          GameActions(
            children: [
              PrismButton(
                tone: PrismButtonTone.filled,
                label: _bingo ? tr(context, 'Finish — bingo!', 'Terminar: ¡bingo!') : tr(context, 'Finish for now', 'Terminar por ahora'),
                onPressed: () => widget.session.finish(
                  GameOutcome(
                    score: _marked.length - 1,
                    max: 24,
                    summary: _bingo
                        ? tr(context, 'Bingo with ${_marked.length - 1} squares', 'Bingo con ${_marked.length - 1} casillas')
                        : tr(context, '${_marked.length - 1} squares done', '${_marked.length - 1} casillas hechas'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rhythm Repeat
// ---------------------------------------------------------------------------

class RhythmGame extends StatefulWidget {
  const RhythmGame({super.key, required this.session});
  final GameSession session;
  @override
  State<RhythmGame> createState() => _RhythmGameState();
}

class _RhythmGameState extends State<RhythmGame> {
  late final math.Random _rng = widget.session.rng(64);
  final _tone = TonePlayer();
  int _round = 0, _score = 0;
  late List<int> _gaps; // ms between beats
  final List<int> _taps = [];
  bool _playing = false;
  int? _pulse;
  String? _result;

  @override
  void initState() {
    super.initState();
    _newRhythm();
  }

  @override
  void dispose() {
    _tone.dispose();
    super.dispose();
  }

  void _newRhythm() {
    final beats = 3 + _round;
    _gaps = [
      for (var i = 0; i < beats; i++) [300, 450, 600][_rng.nextInt(3)],
    ];
    _taps.clear();
    _result = null;
  }

  Future<void> _play() async {
    setState(() => _playing = true);
    for (var i = 0; i <= _gaps.length; i++) {
      if (!mounted) return;
      setState(() => _pulse = i);
      _tone.play(TonePlayer.scale[3], ms: 140);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _pulse = null);
      if (i < _gaps.length) await Future<void>.delayed(Duration(milliseconds: _gaps[i] - 120));
    }
    if (mounted) setState(() => _playing = false);
  }

  void _tap() {
    if (_playing || _result != null) return;
    _tone.play(TonePlayer.scale[5], ms: 120);
    setState(() => _taps.add(DateTime.now().millisecondsSinceEpoch));
    if (_taps.length == _gaps.length + 1) {
      final got = [for (var i = 1; i < _taps.length; i++) _taps[i] - _taps[i - 1]];
      // Generous tolerance: compare the shape (relative gaps), not speed.
      final scale = got.reduce((a, b) => a + b) / _gaps.reduce((a, b) => a + b);
      final err = [for (var i = 0; i < got.length; i++) ((got[i] / scale - _gaps[i]).abs() / _gaps[i])].reduce((a, b) => a + b) / got.length;
      final ok = err < 0.3;
      setState(() {
        _result = ok ? tr(context, '✓ Nice rhythm!', '✓ ¡Buen ritmo!') : tr(context, 'Not quite — try the next one', 'Casi: prueba el siguiente');
        if (ok) _score++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          GameProgress(current: _round + 1, total: 6, trailing: '★ $_score'),
          Text(
            tr(
              context,
              'Listen (or watch the dots), then tap the same rhythm. Speed doesn\'t matter — only the pattern.',
              'Escucha (o mira los puntos) y toca el mismo ritmo. La velocidad no importa, solo el patrón.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i <= _gaps.length; i++) ...[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _pulse == i ? scheme.primary : (i < _taps.length ? scheme.tertiary : scheme.surfaceContainerHighest)),
                ),
                if (i < _gaps.length) SizedBox(width: _gaps[i] / 20),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 160,
            child: Semantics(
              button: true,
              label: tr(context, 'Tap pad', 'Pad para tocar'),
              child: Material(
                color: scheme.primary.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTapDown: (_) => _tap(),
                  child: Center(child: Icon(PhosphorIcons.handTap(), size: 48, color: scheme.primary)),
                ),
              ),
            ),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_result!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          GameActions(
            children: [
              PrismButton(label: tr(context, 'Play rhythm', 'Escuchar ritmo'), icon: PhosphorIcons.play(), onPressed: _playing ? () {} : _play),
              if (_result != null)
                PrismButton(
                  tone: PrismButtonTone.filled,
                  label: tr(context, 'Next', 'Siguiente'),
                  onPressed: () {
                    if (_round + 1 >= 6) {
                      widget.session.finish(GameOutcome(score: _score, max: 6, summary: '$_score / 6'));
                    } else {
                      setState(() {
                        _round++;
                        _newRhythm();
                      });
                    }
                  },
                ),
              if (_result == null && _taps.isNotEmpty) PrismButton(label: tr(context, 'Reset taps', 'Reiniciar'), onPressed: () => setState(_taps.clear)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map Explorer (tap the continent)
// ---------------------------------------------------------------------------

class MapExplorerGame extends StatefulWidget {
  const MapExplorerGame({super.key, required this.session, required this.places});
  final GameSession session;
  final List<(String, String)> places;
  @override
  State<MapExplorerGame> createState() => _MapExplorerGameState();
}

class _MapExplorerGameState extends State<MapExplorerGame> {
  // Rough continent blobs on a 100×60 map: (name, cx, cy, rx, ry).
  static const continents = [
    ('North America', 20.0, 18.0, 13.0, 10.0),
    ('South America', 30.0, 42.0, 7.0, 11.0),
    ('Europe', 51.0, 14.0, 7.0, 5.0),
    ('Africa', 52.0, 34.0, 9.0, 11.0),
    ('Asia', 72.0, 18.0, 17.0, 10.0),
    ('Oceania', 84.0, 42.0, 9.0, 6.0),
    ('Antarctica', 50.0, 56.0, 30.0, 3.0),
  ];
  late final List<(String, String)> _q = shuffled(widget.places, widget.session.rng(65)).take(10).toList();
  int _i = 0, _score = 0;
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (place, answer) = _q[_i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _i + 1, total: _q.length, trailing: '★ $_score'),
        GamePanel(
          child: Column(
            children: [
              GamePrompt(tr(context, 'Where is $place?', '¿Dónde está $place?')),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 100 / 60,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final s = box.maxWidth / 100;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: scheme.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        for (final (name, cx, cy, rx, ry) in continents)
                          Positioned(
                            left: (cx - rx) * s,
                            top: (cy - ry) * s,
                            width: rx * 2 * s,
                            height: ry * 2 * s,
                            child: Semantics(
                              button: true,
                              label: name,
                              child: GestureDetector(
                                onTap: _picked != null
                                    ? null
                                    : () => setState(() {
                                        _picked = name;
                                        if (name == answer) _score++;
                                      }),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.all(Radius.elliptical(rx * s, ry * s)),
                                    color: _picked == null
                                        ? scheme.primary.withValues(alpha: 0.35)
                                        : name == answer
                                        ? scheme.primary
                                        : (name == _picked ? scheme.error.withValues(alpha: 0.7) : scheme.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: _picked != null
                                      ? Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: scheme.onPrimary),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_picked != null) ...[
                const SizedBox(height: 10),
                Text(
                  _picked == answer ? tr(context, '✓ Yes — $answer', '✓ Sí: $answer') : tr(context, '$place is in $answer', '$place está en $answer'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                GameActions(
                  children: [
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Next', 'Siguiente'),
                      onPressed: () {
                        if (_i + 1 >= _q.length) {
                          widget.session.finish(GameOutcome(score: _score, max: _q.length, summary: '$_score / ${_q.length}'));
                        } else {
                          setState(() {
                            _i++;
                            _picked = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Generators: Build a Story · Character Creator · Invent a Creature ·
// Drawing Prompt Jar · Poetry Generator
// ---------------------------------------------------------------------------

/// Rolls random parts; lets the player reroll each, edit and keep notes.
class GeneratorGame extends StatefulWidget {
  const GeneratorGame({super.key, required this.session, required this.parts, required this.title, this.notesHint, this.compose});
  final GameSession session;
  final Map<String, List<String>> parts;
  final String title;
  final String? notesHint;

  /// Turns the rolled parts into a sentence.
  final String Function(Map<String, String> picks)? compose;
  @override
  State<GeneratorGame> createState() => _GeneratorGameState();
}

class _GeneratorGameState extends State<GeneratorGame> {
  late final math.Random _rng = widget.session.rng(66);
  late final Map<String, String> _picks = {for (final e in widget.parts.entries) e.key: e.value[_rng.nextInt(e.value.length)]};
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composed = widget.compose?.call(_picks);
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final e in _picks.entries)
            OptionTile(
              leading: SizedBox(width: 74, child: Text(e.key, style: Theme.of(context).textTheme.labelMedium)),
              label: e.value,
              onTap: () => setState(() => _picks[e.key] = widget.parts[e.key]![_rng.nextInt(widget.parts[e.key]!.length)]),
            ),
          Text(tr(context, 'Tap any line to re-roll it.', 'Toca una línea para cambiarla.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          if (composed != null) ...[
            const SizedBox(height: 10),
            GamePanel(
              child: Text(composed, style: const TextStyle(fontStyle: FontStyle.italic, height: 1.45)),
            ),
          ],
          const SizedBox(height: 10),
          PrismTextField(controller: _notes, maxLines: 6, hintText: widget.notesHint ?? tr(context, 'Write, describe or plan…', 'Escribe, describe o planea…')),
          GameActions(
            children: [
              PrismButton(
                label: tr(context, 'Re-roll all', 'Cambiar todo'),
                icon: PhosphorIcons.shuffle(),
                onPressed: () => setState(() {
                  for (final k in _picks.keys) {
                    _picks[k] = widget.parts[k]![_rng.nextInt(widget.parts[k]!.length)];
                  }
                }),
              ),
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Keep it', 'Guardarlo'),
                onPressed: () {
                  final text = [composed ?? _picks.entries.map((e) => '${e.key}: ${e.value}').join(' · '), if (_notes.text.trim().isNotEmpty) _notes.text.trim()].join('\n');
                  widget.session.finish(GameOutcome(summary: widget.title, memorable: text, details: {'picks': _picks, 'notes': _notes.text}));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Magnetic-poetry board: tap word tiles to build lines.
class PoetryGame extends StatefulWidget {
  const PoetryGame({super.key, required this.session, required this.words});
  final GameSession session;
  final List<String> words;
  @override
  State<PoetryGame> createState() => _PoetryGameState();
}

class _PoetryGameState extends State<PoetryGame> {
  late final math.Random _rng = widget.session.rng(67);
  late List<String> _tiles = shuffled(widget.words, _rng).take(28).toList();
  final List<List<String>> _lines = [[]];

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var l = 0; l < _lines.length; l++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var k = 0; k < _lines[l].length; k++) GestureDetector(onTap: () => setState(() => _lines[l].removeAt(k)), child: Chip2(_lines[l][k])),
                  if (_lines[l].isEmpty) Text(tr(context, 'Line ${l + 1} — tap words below', 'Línea ${l + 1}: toca palabras abajo'), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          const Divider(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final w in _tiles) PrismChip(label: w, selected: false, onTap: () => setState(() => _lines.last.add(w)))],
          ),
          GameActions(
            children: [
              PrismButton(label: tr(context, 'New line', 'Nueva línea'), onPressed: () => setState(() => _lines.add([]))),
              PrismButton(label: tr(context, 'New words', 'Nuevas palabras'), icon: PhosphorIcons.shuffle(), onPressed: () => setState(() => _tiles = shuffled(widget.words, _rng).take(28).toList())),
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Keep poem', 'Guardar poema'),
                onPressed: () {
                  final poem = _lines.where((l) => l.isNotEmpty).map((l) => l.join(' ')).join('\n');
                  widget.session.finish(GameOutcome(summary: tr(context, 'A new poem', 'Un poema nuevo'), memorable: poem.isEmpty ? null : poem));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A one-off prompt from a jar, with a timer-free "I did it" and notes.
class PromptJarGame extends StatefulWidget {
  const PromptJarGame({super.key, required this.session, required this.prompts, required this.emoji});
  final GameSession session;
  final List<String> prompts;
  final String emoji;
  @override
  State<PromptJarGame> createState() => _PromptJarGameState();
}

class _PromptJarGameState extends State<PromptJarGame> {
  late final math.Random _rng = widget.session.rng(68);
  late int _i = _rng.nextInt(widget.prompts.length);
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          GamePrompt(widget.prompts[_i]),
          const SizedBox(height: 12),
          PrismTextField(controller: _ctl, maxLines: 4, hintText: tr(context, 'Notes, a description, or what you made (optional)', 'Notas, descripción o lo que hiciste (opcional)')),
          GameActions(
            children: [
              PrismButton(label: tr(context, 'Another', 'Otro'), icon: PhosphorIcons.shuffle(), onPressed: () => setState(() => _i = _rng.nextInt(widget.prompts.length))),
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Done', 'Hecho'),
                onPressed: () => widget.session.finish(GameOutcome(summary: widget.prompts[_i], memorable: _ctl.text.trim().isEmpty ? null : _ctl.text.trim())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Untimed ticker used by some activities to show elapsed time.
class Elapsed extends StatefulWidget {
  const Elapsed({super.key});
  @override
  State<Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<Elapsed> {
  final _start = DateTime.now();
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = DateTime.now().difference(_start).inSeconds;
    return Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}');
  }
}
