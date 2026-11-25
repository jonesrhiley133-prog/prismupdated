import 'dart:math' as math;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// One multiple-choice question. The first option is correct; options are
/// shuffled when shown.
class Q {
  const Q(this.q, this.options, [this.explain = '', this.d = 2]);
  final String q;
  final List<String> options;
  final String explain;

  /// 1 easy, 2 medium, 3 hard.
  final int d;

  String get answer => options.first;
}

/// Plays a set of questions: difficulty choice, optional timer, an
/// explanation after each answer and a score at the end.
class QuizGame extends StatefulWidget {
  const QuizGame({
    super.key,
    required this.session,
    required this.bank,
    this.count = 10,
    this.askDifficulty = true,
    this.marathon = false,
    this.seconds = 20,
    this.promptSize = 19,
  });
  final GameSession session;
  final List<Q> bank;
  final int count;
  final bool askDifficulty;

  /// Questions get harder as the round goes on.
  final bool marathon;
  final int seconds;
  final double promptSize;

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  int? _difficulty; // 0 = mixed
  List<Q> _qs = const [];
  List<List<String>> _opts = const [];
  int _i = 0;
  int _score = 0;
  String? _picked;
  bool _timedOut = false;
  final List<String> _missed = [];

  @override
  void initState() {
    super.initState();
    if (!widget.askDifficulty || widget.marathon) _begin(0);
  }

  void _begin(int difficulty) {
    final rng = widget.session.rng();
    var pool = difficulty == 0
        ? widget.bank
        : widget.bank.where((q) => q.d == difficulty).toList();
    if (pool.length < 4) pool = widget.bank;
    var picked = shuffled(
      pool,
      rng,
    ).take(math.min(widget.count, pool.length)).toList();
    if (widget.marathon) picked.sort((a, b) => a.d.compareTo(b.d));
    setState(() {
      _difficulty = difficulty;
      _qs = picked;
      _opts = [for (final q in picked) shuffled(q.options, rng)];
    });
  }

  void _answer(String? o) {
    if (_picked != null || _timedOut) return;
    setState(() {
      if (o == null) {
        _timedOut = true;
      } else {
        _picked = o;
        if (o == _qs[_i].answer) {
          _score++;
        }
      }
      if (o != _qs[_i].answer) _missed.add(_qs[_i].q);
    });
  }

  void _next() {
    if (_i + 1 >= _qs.length) {
      widget.session.finish(
        GameOutcome(
          score: _score,
          max: _qs.length,
          summary: '$_score / ${_qs.length}',
          details: {'missed': _missed},
        ),
      );
      return;
    }
    setState(() {
      _i++;
      _picked = null;
      _timedOut = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_difficulty == null) {
      return GamePanel(
        child: Column(
          children: [
            GamePrompt(tr(context, 'Pick a difficulty', 'Elige la dificultad')),
            const SizedBox(height: 14),
            for (final (d, label) in [
              (1, tr(context, 'Easy', 'Fácil')),
              (2, tr(context, 'Medium', 'Media')),
              (3, tr(context, 'Hard', 'Difícil')),
              (0, tr(context, 'Mixed', 'Mezcla')),
            ])
              OptionTile(label: label, onTap: () => _begin(d)),
          ],
        ),
      );
    }
    if (_qs.isEmpty)
      return GamePanel(
        child: Text(tr(context, 'No questions yet.', 'Aún no hay preguntas.')),
      );
    final q = _qs[_i];
    final answered = _picked != null || _timedOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _i + 1, total: _qs.length, trailing: '★ $_score'),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.session.timer && !answered)
                Align(
                  alignment: Alignment.centerRight,
                  child: GameTimer(
                    key: ValueKey(_i),
                    seconds: widget.seconds,
                    onDone: () => _answer(null),
                  ),
                ),
              GamePrompt(q.q, size: widget.promptSize),
              const SizedBox(height: 14),
              for (final o in _opts[_i])
                OptionTile(
                  label: o,
                  state: !answered
                      ? null
                      : (o == q.answer ? true : (o == _picked ? false : null)),
                  onTap: answered ? null : () => _answer(o),
                ),
              if (answered) ...[
                const SizedBox(height: 10),
                Text(
                  _picked == q.answer
                      ? tr(context, 'Correct!', '¡Correcto!')
                      : _timedOut
                      ? tr(
                          context,
                          'Time\'s up — the answer is ${q.answer}.',
                          'Se acabó el tiempo: la respuesta es ${q.answer}.',
                        )
                      : tr(
                          context,
                          'The answer is ${q.answer}.',
                          'La respuesta es ${q.answer}.',
                        ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (q.explain.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    q.explain,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
                GameActions(
                  children: [
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: _i + 1 >= _qs.length
                          ? tr(context, 'See results', 'Ver resultados')
                          : tr(context, 'Next', 'Siguiente'),
                      onPressed: _next,
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

/// A quiz whose questions are made on the fly from [make] (maths, sequences,
/// balance puzzles…). [make] gets a seeded random and a difficulty.
class GeneratedQuiz extends StatelessWidget {
  const GeneratedQuiz({
    super.key,
    required this.session,
    required this.make,
    this.count = 10,
    this.seconds = 20,
  });
  final GameSession session;
  final Q Function(math.Random rng, int difficulty) make;
  final int count;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final rng = session.rng(7);
    final bank = [
      for (var d = 1; d <= 3; d++)
        for (var i = 0; i < count; i++) make(rng, d),
    ];
    return QuizGame(
      session: session,
      bank: bank,
      count: count,
      seconds: seconds,
    );
  }
}

/// Distinct wrong numeric options near [answer].
List<String> numberOptions(int answer, math.Random rng, {int spread = 5}) {
  final out = <int>{answer};
  var guard = 0;
  while (out.length < 4 && guard++ < 50) {
    final d = rng.nextInt(spread * 2 + 1) - spread;
    if (d != 0) out.add(answer + d);
  }
  var k = 1;
  while (out.length < 4) {
    out.add(answer + spread + k++);
  }
  final list = out.toList()..remove(answer);
  return ['$answer', for (final v in list.take(3)) '$v'];
}
