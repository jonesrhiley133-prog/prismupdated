import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// The bundled word list (ENABLE, 3–7 letters), loaded on first use.
abstract final class GameDictionary {
  static Set<String>? _words;
  static Future<Set<String>>? _loading;

  static Future<Set<String>> load() {
    if (_words != null) return Future.value(_words);
    return _loading ??= rootBundle
        .loadString('assets/games/words.txt')
        .then(
          (t) => _words = t
              .split('\n')
              .map((w) => w.trim())
              .where((w) => w.isNotEmpty)
              .toSet(),
        );
  }

  static bool contains(String w) => _words?.contains(w.toLowerCase()) ?? false;
}

/// Waits for the dictionary, then builds [child].
class WithDictionary extends StatelessWidget {
  const WithDictionary({super.key, required this.builder});
  final Widget Function(Set<String> words) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<Set<String>>(
    future: GameDictionary.load(),
    builder: (context, s) => s.hasData
        ? builder(s.data!)
        : const Padding(
            padding: EdgeInsets.all(40),
            child: PrismLoadingState(),
          ),
  );
}

/// Letter tiles in a row.
class LetterTiles extends StatelessWidget {
  const LetterTiles(
    this.letters, {
    super.key,
    this.size = 40,
    this.onTap,
    this.used = const {},
    this.colors,
  });
  final List<String> letters;
  final double size;
  final void Function(int index)? onTap;
  final Set<int> used;
  final List<Color?>? colors;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < letters.length; i++)
          Semantics(
            button: onTap != null,
            label: letters[i],
            child: GestureDetector(
              onTap: onTap == null || used.contains(i) ? null : () => onTap!(i),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: used.contains(i) ? 0.25 : 1,
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors?[i] ?? scheme.surfaceContainerHighest,
                    borderRadius: prismCorners(context, size * 0.22),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    letters[i].toUpperCase(),
                    style: TextStyle(
                      fontSize: size * 0.48,
                      fontWeight: FontWeight.w800,
                      color: colors?[i] == null
                          ? scheme.onSurface
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A–Z keyboard. [states]: letter → true (good), false (absent), null (present elsewhere).
class GameKeyboard extends StatelessWidget {
  const GameKeyboard({
    super.key,
    required this.onKey,
    this.onEnter,
    this.onBack,
    this.disabled = const {},
    this.states = const {},
  });
  final void Function(String) onKey;
  final VoidCallback? onEnter;
  final VoidCallback? onBack;
  final Set<String> disabled;
  final Map<String, bool?> states;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    Widget key(
      String label,
      VoidCallback? onTap, {
      double flex = 1,
      String? semantic,
    }) {
      final st = states[label];
      final has = states.containsKey(label);
      return Expanded(
        flex: (flex * 10).round(),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: Semantics(
            button: true,
            label: semantic ?? label,
            child: Material(
              color: !has
                  ? scheme.surfaceContainerHighest
                  : st == true
                  ? scheme.primary
                  : st == null
                  ? scheme.tertiary
                  : scheme.surfaceContainerLow,
              borderRadius: prismCorners(context, 8),
              child: InkWell(
                borderRadius: prismCorners(context, 8),
                onTap: onTap,
                child: SizedBox(
                  height: 46,
                  child: Center(
                    child: Text(
                      label.length == 1 ? label.toUpperCase() : label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: label.length == 1 ? 16 : 12,
                        color: has && st != false
                            ? Colors.white
                            : (disabled.contains(label)
                                  ? scheme.onSurface.withValues(alpha: 0.3)
                                  : scheme.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++)
          Row(
            children: [
              if (r == 2 && onEnter != null)
                key('Enter', onEnter, flex: 1.6, semantic: 'Enter'),
              for (final c in rows[r].split(''))
                key(c, disabled.contains(c) ? null : () => onKey(c)),
              if (r == 2 && onBack != null)
                key('⌫', onBack, flex: 1.6, semantic: 'Delete'),
            ],
          ),
      ],
    );
  }
}

String _scramble(String w, math.Random rng) {
  if (w.length < 2) return w;
  for (var i = 0; i < 10; i++) {
    final s = (w.split('')..shuffle(rng)).join();
    if (s != w) return s;
  }
  return w.split('').reversed.join();
}

// ---------------------------------------------------------------------------
// Word Scramble · Missing Letters (type-the-word rounds)
// ---------------------------------------------------------------------------

enum TypeMode { scramble, missing }

class TypeWordGame extends StatefulWidget {
  const TypeWordGame({
    super.key,
    required this.session,
    required this.words,
    required this.mode,
    this.rounds = 8,
  });
  final GameSession session;
  final List<(String, String)> words;
  final TypeMode mode;
  final int rounds;
  @override
  State<TypeWordGame> createState() => _TypeWordGameState();
}

class _TypeWordGameState extends State<TypeWordGame> {
  late final rng = widget.session.rng(1);
  late final List<(String, String)> _round = shuffled(
    widget.words,
    rng,
  ).take(widget.rounds).toList();
  late final List<String> _shown = [
    for (final (w, _) in _round)
      widget.mode == TypeMode.scramble
          ? _scramble(w, rng)
          : () {
              final hide = <int>{};
              final n = math.max(1, (w.length * 0.45).round());
              while (hide.length < n) {
                hide.add(rng.nextInt(w.length));
              }
              return [
                for (var i = 0; i < w.length; i++)
                  hide.contains(i) ? '_' : w[i],
              ].join();
            }(),
  ];
  int _i = 0, _score = 0;
  final _ctl = TextEditingController();
  bool? _right;
  bool _hint = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _check() {
    final ok = _ctl.text.trim().toLowerCase() == _round[_i].$1;
    setState(() {
      _right = ok;
      if (ok) _score += _hint ? 1 : 2;
    });
  }

  void _next() {
    if (_i + 1 >= _round.length) {
      widget.session.finish(
        GameOutcome(
          score: _score,
          max: _round.length * 2,
          summary: tr(context, '$_score points', '$_score puntos'),
        ),
      );
      return;
    }
    setState(() {
      _i++;
      _right = null;
      _hint = false;
      _ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final (word, hint) = _round[_i];
    final shown = _shown[_i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(
          current: _i + 1,
          total: _round.length,
          trailing: '★ $_score',
        ),
        GamePanel(
          child: Column(
            children: [
              LetterTiles(shown.split(''), size: shown.length > 7 ? 34 : 42),
              const SizedBox(height: 10),
              Text(
                _hint
                    ? '${tr(context, 'Hint', 'Pista')}: $hint · ${word[0].toUpperCase()}…'
                    : tr(
                        context,
                        '${word.length} letters',
                        '${word.length} letras',
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              PrismTextField(
                controller: _ctl,
                hintText: tr(context, 'Type the word', 'Escribe la palabra'),
                autofocus: true,
                onSubmitted: (_) => _right == null ? _check() : _next(),
              ),
              if (_right != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _right!
                        ? tr(context, '✓ Correct!', '✓ ¡Correcto!')
                        : tr(context, '✗ It was "$word"', '✗ Era "$word"'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              GameActions(
                children: _right == null
                    ? [
                        if (!_hint)
                          PrismButton(
                            label: tr(context, 'Hint', 'Pista'),
                            icon: PhosphorIcons.lightbulb(),
                            onPressed: () => setState(() => _hint = true),
                          ),
                        PrismButton(
                          label: tr(context, 'Skip', 'Saltar'),
                          onPressed: () => setState(() => _right = false),
                        ),
                        PrismButton(
                          tone: PrismButtonTone.filled,
                          label: tr(context, 'Check', 'Comprobar'),
                          onPressed: _check,
                        ),
                      ]
                    : [
                        PrismButton(
                          tone: PrismButtonTone.filled,
                          label: tr(context, 'Next', 'Siguiente'),
                          onPressed: _next,
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
// Hangman
// ---------------------------------------------------------------------------

class HangmanGame extends StatefulWidget {
  const HangmanGame({super.key, required this.session, required this.words});
  final GameSession session;
  final List<(String, String)> words;
  @override
  State<HangmanGame> createState() => _HangmanGameState();
}

class _HangmanGameState extends State<HangmanGame> {
  late final (String, String) _w =
      widget.words[widget.session.rng(2).nextInt(widget.words.length)];
  final Set<String> _guessed = {};
  static const _lives = 7;

  int get _wrong => _guessed.where((c) => !_w.$1.contains(c)).length;
  bool get _won => _w.$1.split('').every(_guessed.contains);

  void _guess(String c) {
    setState(() => _guessed.add(c));
    if (_won || _wrong >= _lives) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted)
          widget.session.finish(
            GameOutcome(
              score: _won ? _lives - _wrong : 0,
              max: _lives,
              summary: _won
                  ? tr(context, 'Solved "${_w.$1}"', 'Resuelta: "${_w.$1}"')
                  : tr(
                      context,
                      'The word was "${_w.$1}"',
                      'La palabra era "${_w.$1}"',
                    ),
            ),
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lives = _lives - _wrong;
    return GamePanel(
      child: Column(
        children: [
          Text(
            '${tr(context, 'Hint', 'Pista')}: ${_w.$2}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // A gentle "lives" garland instead of a gallows.
          Text(
            List.generate(_lives, (i) => i < lives ? '🌸' : '🍂').join(' '),
            style: const TextStyle(fontSize: 22),
            semanticsLabel: tr(
              context,
              '$lives tries left',
              'Quedan $lives intentos',
            ),
          ),
          const SizedBox(height: 14),
          LetterTiles([
            for (final c in _w.$1.split(''))
              _guessed.contains(c) || _wrong >= _lives ? c : ' ',
          ], size: 38),
          const SizedBox(height: 16),
          GameKeyboard(
            onKey: _won || _wrong >= _lives ? (_) {} : _guess,
            disabled: _guessed,
            states: {
              for (final c in _guessed) c: _w.$1.contains(c) ? true : false,
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Five-Letter Guess
// ---------------------------------------------------------------------------

class FiveLetterGame extends StatefulWidget {
  const FiveLetterGame({
    super.key,
    required this.session,
    required this.answers,
    required this.words,
  });
  final GameSession session;
  final List<String> answers;
  final Set<String> words;
  @override
  State<FiveLetterGame> createState() => _FiveLetterGameState();
}

class _FiveLetterGameState extends State<FiveLetterGame> {
  late final String _answer =
      widget.answers[widget.session.rng(3).nextInt(widget.answers.length)];
  late final List<String> _guesses = [
    for (final g in (widget.session.saved?['guesses'] as List?) ?? const [])
      '$g',
  ];
  String _cur = '';
  String? _msg;

  List<bool?> _score(String g) {
    final res = List<bool?>.filled(5, false);
    final left = <String, int>{};
    for (var i = 0; i < 5; i++) {
      if (g[i] == _answer[i]) {
        res[i] = true;
      } else {
        left[_answer[i]] = (left[_answer[i]] ?? 0) + 1;
      }
    }
    for (var i = 0; i < 5; i++) {
      if (res[i] == true) continue;
      if ((left[g[i]] ?? 0) > 0) {
        res[i] = null;
        left[g[i]] = left[g[i]]! - 1;
      }
    }
    return res;
  }

  void _enter() {
    if (_cur.length != 5)
      return setState(
        () => _msg = tr(
          context,
          'Five letters, please',
          'Cinco letras, por favor',
        ),
      );
    if (!widget.words.contains(_cur) && !widget.answers.contains(_cur))
      return setState(
        () => _msg = tr(context, 'Not in the word list', 'No está en la lista'),
      );
    setState(() {
      _guesses.add(_cur);
      _cur = '';
      _msg = null;
    });
    widget.session.save({'guesses': _guesses});
    if (_guesses.last == _answer || _guesses.length >= 6) {
      final won = _guesses.last == _answer;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted)
          widget.session.finish(
            GameOutcome(
              score: won ? 7 - _guesses.length : 0,
              max: 6,
              summary: won
                  ? tr(
                      context,
                      'Solved in ${_guesses.length}',
                      'Resuelto en ${_guesses.length}',
                    )
                  : tr(
                      context,
                      'The word was "$_answer"',
                      'La palabra era "$_answer"',
                    ),
            ),
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final states = <String, bool?>{};
    for (final g in _guesses) {
      final s = _score(g);
      for (var i = 0; i < 5; i++) {
        final prev = states[g[i]];
        if (s[i] == true || prev == true) {
          states[g[i]] = true;
        } else if (s[i] == null || (states.containsKey(g[i]) && prev == null)) {
          states[g[i]] = null;
        } else {
          states.putIfAbsent(g[i], () => false);
        }
      }
    }
    Color? colorOf(bool? v) => v == true
        ? scheme.primary
        : v == null
        ? scheme.tertiary
        : scheme.outline;
    final done =
        _guesses.isNotEmpty &&
        (_guesses.last == _answer || _guesses.length >= 6);
    return GamePanel(
      child: Column(
        children: [
          for (var r = 0; r < 6; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: r < _guesses.length
                  ? Builder(
                      builder: (context) {
                        final s = _score(_guesses[r]);
                        return LetterTiles(
                          [for (var i = 0; i < 5; i++) _guesses[r][i]],
                          size: 46,
                          colors: [for (final v in s) colorOf(v)],
                        );
                      },
                    )
                  : LetterTiles(
                      List.generate(
                        5,
                        (i) => r == _guesses.length && i < _cur.length
                            ? _cur[i]
                            : ' ',
                      ),
                      size: 46,
                    ),
            ),
          const SizedBox(height: 6),
          Text(
            tr(
              context,
              'Filled = right spot · tinted = in the word · grey = not in it',
              'Relleno = sitio correcto · tono = está en la palabra · gris = no está',
            ),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_msg!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 10),
          if (!done)
            GameKeyboard(
              states: states,
              onKey: (c) => _cur.length < 5 ? setState(() => _cur += c) : null,
              onBack: () => _cur.isEmpty
                  ? null
                  : setState(() => _cur = _cur.substring(0, _cur.length - 1)),
              onEnter: _enter,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word Ladder
// ---------------------------------------------------------------------------

class WordLadderGame extends StatefulWidget {
  const WordLadderGame({
    super.key,
    required this.session,
    required this.ladders,
    required this.words,
  });
  final GameSession session;
  final List<(String, String, List<String>)> ladders;
  final Set<String> words;
  @override
  State<WordLadderGame> createState() => _WordLadderGameState();
}

class _WordLadderGameState extends State<WordLadderGame> {
  late final (String, String, List<String>) _l =
      widget.ladders[widget.session.rng(4).nextInt(widget.ladders.length)];
  late final List<String> _steps = [_l.$1];
  final _ctl = TextEditingController();
  String? _msg;
  int _hints = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _oneOff(String a, String b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) d++;
    }
    return d == 1;
  }

  void _add([String? word]) {
    final w = (word ?? _ctl.text).trim().toLowerCase();
    if (!_oneOff(_steps.last, w))
      return setState(
        () => _msg = tr(
          context,
          'Change exactly one letter',
          'Cambia exactamente una letra',
        ),
      );
    if (!widget.words.contains(w))
      return setState(
        () => _msg = tr(
          context,
          '"$w" isn\'t in the word list',
          '"$w" no está en la lista',
        ),
      );
    setState(() {
      _steps.add(w);
      _ctl.clear();
      _msg = null;
    });
    if (w == _l.$2) {
      final best = _l.$3.length - 1;
      final used = _steps.length - 1;
      widget.session.finish(
        GameOutcome(
          score: math.max(1, 10 - (used - best) * 2 - _hints * 2),
          max: 10,
          summary: tr(
            context,
            '${_l.$1} → ${_l.$2} in $used steps (shortest known: $best)',
            '${_l.$1} → ${_l.$2} en $used pasos (mínimo conocido: $best)',
          ),
          memorable: _steps.join(' → '),
        ),
      );
    }
  }

  void _hint() {
    // Next word on the known path from the furthest point we've matched.
    final path = _l.$3;
    final at = path.lastIndexOf(_steps.last);
    if (at >= 0 && at + 1 < path.length) {
      _hints++;
      _add(path[at + 1]);
    } else {
      setState(
        () => _msg = tr(
          context,
          'Off the known path — undo a step for a hint',
          'Fuera del camino conocido: deshaz un paso para una pista',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      child: Column(
        children: [
          GamePrompt('${_l.$1.toUpperCase()}  →  ${_l.$2.toUpperCase()}'),
          const SizedBox(height: 4),
          Text(
            tr(
              context,
              'Change one letter at a time; every step must be a real word.',
              'Cambia una letra cada vez; cada paso debe ser una palabra real.',
            ),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          for (final s in _steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: LetterTiles(s.split(''), size: 36),
            ),
          const SizedBox(height: 10),
          PrismTextField(
            controller: _ctl,
            hintText: tr(context, 'Next word', 'Siguiente palabra'),
            onSubmitted: (_) => _add(),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _msg!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          GameActions(
            children: [
              if (_steps.length > 1)
                PrismButton(
                  label: tr(context, 'Undo', 'Deshacer'),
                  icon: PhosphorIcons.arrowUUpLeft(),
                  onPressed: () => setState(() => _steps.removeLast()),
                ),
              PrismButton(
                label: tr(context, 'Hint', 'Pista'),
                icon: PhosphorIcons.lightbulb(),
                onPressed: _hint,
              ),
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Add', 'Añadir'),
                onPressed: _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anagram Challenge
// ---------------------------------------------------------------------------

bool _canMake(String word, Map<String, int> pool) {
  final need = <String, int>{};
  for (final c in word.split('')) {
    need[c] = (need[c] ?? 0) + 1;
    if (need[c]! > (pool[c] ?? 0)) return false;
  }
  return true;
}

class AnagramGame extends StatefulWidget {
  const AnagramGame({super.key, required this.session, required this.words});
  final GameSession session;
  final Set<String> words;
  @override
  State<AnagramGame> createState() => _AnagramGameState();
}

class _AnagramGameState extends State<AnagramGame> {
  late final String _base;
  late final List<String> _letters;
  late final Set<String> _possible;
  final Set<String> _found = {};
  final _ctl = TextEditingController();
  String? _msg;

  @override
  void initState() {
    super.initState();
    final rng = widget.session.rng(5);
    final sevens =
        widget.words.where((w) => w.length == 7 && !w.endsWith('s')).toList()
          ..sort();
    _base = sevens[rng.nextInt(sevens.length)];
    _letters = _base.split('')..shuffle(rng);
    final pool = <String, int>{};
    for (final c in _letters) {
      pool[c] = (pool[c] ?? 0) + 1;
    }
    _possible = {
      for (final w in widget.words)
        if (w.length >= 3 && _canMake(w, pool)) w,
    };
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _try() {
    final w = _ctl.text.trim().toLowerCase();
    _ctl.clear();
    if (_found.contains(w))
      return setState(
        () => _msg = tr(context, 'Already found', 'Ya encontrada'),
      );
    if (!_possible.contains(w))
      return setState(
        () => _msg = tr(context, '"$w" doesn\'t work', '"$w" no vale'),
      );
    setState(() {
      _found.add(w);
      _msg = w.length == 7
          ? tr(
              context,
              '🌟 You found the seven-letter word!',
              '🌟 ¡Encontraste la palabra de siete letras!',
            )
          : null;
    });
  }

  void _finish() {
    final pts = _found.fold(0, (t, w) => t + w.length - 2);
    widget.session.finish(
      GameOutcome(
        score: pts,
        summary: tr(
          context,
          '${_found.length} of ${_possible.length} words',
          '${_found.length} de ${_possible.length} palabras',
        ),
        memorable: tr(
          context,
          'The seven-letter word was "$_base"',
          'La palabra de siete letras era "$_base"',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      child: Column(
        children: [
          if (widget.session.timer)
            Align(
              alignment: Alignment.centerRight,
              child: GameTimer(seconds: 180, onDone: _finish),
            ),
          LetterTiles(_letters, size: 42),
          const SizedBox(height: 8),
          TextButtonLike(
            label: tr(context, 'Shuffle', 'Mezclar'),
            onTap: () => setState(() => _letters.shuffle()),
          ),
          const SizedBox(height: 8),
          PrismTextField(
            controller: _ctl,
            hintText: tr(
              context,
              'Words of 3+ letters',
              'Palabras de 3+ letras',
            ),
            onSubmitted: (_) => _try(),
          ),
          if (_msg != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_msg!)),
          const SizedBox(height: 10),
          Text(
            tr(
              context,
              'Found ${_found.length} of ${_possible.length}',
              'Encontradas ${_found.length} de ${_possible.length}',
            ),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final w in _found.toList()..sort()) Chip2(w)],
          ),
          GameActions(
            children: [
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Finish', 'Terminar'),
                onPressed: _finish,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minimal pill used for found words.
class Chip2 extends StatelessWidget {
  const Chip2(this.label, {super.key, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: prismCorners(context, 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// A quiet text action (no stock TextButton).
class TextButtonLike extends StatelessWidget {
  const TextButtonLike({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PrismButton(
    density: PrismControlDensity.compact,
    label: label,
    onPressed: onTap,
  );
}

// ---------------------------------------------------------------------------
// Word Chain (take turns) · Category Sprint · Alphabet Challenge
// ---------------------------------------------------------------------------

class WordChainGame extends StatefulWidget {
  const WordChainGame({super.key, required this.session, required this.words});
  final GameSession session;
  final Set<String> words;
  @override
  State<WordChainGame> createState() => _WordChainGameState();
}

class _WordChainGameState extends State<WordChainGame> {
  late final List<String> _chain = [
    () {
      final starts = widget.words.where((w) => w.length == 5).toList()..sort();
      return starts[widget.session.rng(6).nextInt(starts.length)];
    }(),
  ];
  final List<String?> _by = [null];
  final _ctl = TextEditingController();
  String? _msg;
  int _turn = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String? get _player => widget.session.players.isEmpty
      ? null
      : widget.session.players[_turn % widget.session.players.length];

  void _add() {
    final w = _ctl.text.trim().toLowerCase();
    final last = _chain.last[_chain.last.length - 1];
    if (!w.startsWith(last))
      return setState(
        () => _msg = tr(
          context,
          'Start with "${last.toUpperCase()}"',
          'Empieza por "${last.toUpperCase()}"',
        ),
      );
    if (_chain.contains(w))
      return setState(() => _msg = tr(context, 'Already used', 'Ya usada'));
    if (!widget.words.contains(w))
      return setState(
        () => _msg = tr(
          context,
          '"$w" isn\'t in the word list',
          '"$w" no está en la lista',
        ),
      );
    setState(() {
      _chain.add(w);
      _by.add(_player);
      _ctl.clear();
      _msg = null;
      _turn++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _chain.last[_chain.last.length - 1].toUpperCase();
    return GamePanel(
      child: Column(
        children: [
          if (_player != null)
            Text(
              tr(
                context,
                '${widget.session.nameOf(_player)}\'s turn',
                'Turno de ${widget.session.nameOf(_player)}',
              ),
              style: theme.textTheme.titleSmall,
            ),
          GamePrompt(
            tr(
              context,
              'Next word starts with $last',
              'La siguiente empieza por $last',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [for (final w in _chain) Chip2(w)],
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _ctl,
            hintText: tr(context, 'Your word', 'Tu palabra'),
            onSubmitted: (_) => _add(),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _msg!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          GameActions(
            children: [
              PrismButton(
                label: tr(context, 'End chain', 'Terminar cadena'),
                onPressed: () {
                  final counts = <String, int>{};
                  for (final b in _by.skip(1)) {
                    if (b != null) counts[b] = (counts[b] ?? 0) + 1;
                  }
                  widget.session.finish(
                    GameOutcome(
                      score: _chain.length - 1,
                      summary: tr(
                        context,
                        'A chain of ${_chain.length} words',
                        'Una cadena de ${_chain.length} palabras',
                      ),
                      memorable: _chain.join(' → '),
                      details: counts,
                    ),
                  );
                },
              ),
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Add', 'Añadir'),
                onPressed: _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryGame extends StatefulWidget {
  const CategoryGame({
    super.key,
    required this.session,
    required this.categories,
    required this.alphabet,
  });
  final GameSession session;
  final Map<String, List<String>> categories;

  /// Alphabet Challenge: one answer per letter.
  final bool alphabet;
  @override
  State<CategoryGame> createState() => _CategoryGameState();
}

class _CategoryGameState extends State<CategoryGame> {
  late final String _cat =
      (widget.categories.keys.toList()..shuffle(widget.session.rng(8))).first;
  final Map<String, String> _byLetter = {};
  final List<String> _list = [];
  final _ctl = TextEditingController();
  String? _msg;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _known(String w) => widget.categories[_cat]!.contains(w);

  void _add() {
    final w = _ctl.text.trim().toLowerCase().replaceAll(' ', '');
    _ctl.clear();
    if (w.isEmpty) return;
    setState(() {
      if (widget.alphabet) {
        _byLetter[w[0]] = w;
      } else if (!_list.contains(w)) {
        _list.add(w);
      }
      _msg = _known(w)
          ? null
          : tr(
              context,
              '"$w" isn\'t on our list — kept, but no point',
              '"$w" no está en nuestra lista: se guarda, sin punto',
            );
    });
  }

  void _finish() {
    final answers = widget.alphabet ? _byLetter.values.toList() : _list;
    final pts = answers.where(_known).length;
    widget.session.finish(
      GameOutcome(
        score: pts,
        summary: tr(
          context,
          '$pts recognised answers',
          '$pts respuestas reconocidas',
        ),
        memorable: answers.take(12).join(', '),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      child: Column(
        children: [
          if (widget.session.timer)
            Align(
              alignment: Alignment.centerRight,
              child: GameTimer(
                seconds: widget.alphabet ? 240 : 60,
                onDone: _finish,
              ),
            ),
          Text(
            tr(context, 'Category', 'Categoría'),
            style: theme.textTheme.labelMedium,
          ),
          GamePrompt(_cat),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _ctl,
            hintText: widget.alphabet
                ? tr(
                    context,
                    'One answer per letter',
                    'Una respuesta por letra',
                  )
                : tr(context, 'Type answers', 'Escribe respuestas'),
            onSubmitted: (_) => _add(),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_msg!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          if (widget.alphabet)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in 'abcdefghijklmnopqrstuvwxyz'.split(''))
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _byLetter[c] == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : (_known(_byLetter[c]!)
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.18,
                                  )
                                : theme.colorScheme.tertiary.withValues(
                                    alpha: 0.14,
                                  )),
                      borderRadius: prismCorners(context, 8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          c.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          _byLetter[c] ?? '',
                          style: theme.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in _list)
                  Chip2(
                    w,
                    color: _known(w) ? null : theme.colorScheme.tertiary,
                  ),
              ],
            ),
          GameActions(
            children: [
              PrismButton(
                tone: PrismButtonTone.filled,
                label: tr(context, 'Finish', 'Terminar'),
                onPressed: _finish,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hidden Word
// ---------------------------------------------------------------------------

class HiddenWordGame extends StatefulWidget {
  const HiddenWordGame({
    super.key,
    required this.session,
    required this.puzzles,
    this.rounds = 4,
  });
  final GameSession session;
  final List<(String, List<String>)> puzzles;
  final int rounds;
  @override
  State<HiddenWordGame> createState() => _HiddenWordGameState();
}

class _HiddenWordGameState extends State<HiddenWordGame> {
  late final List<(String, List<String>)> _round = shuffled(
    widget.puzzles,
    widget.session.rng(9),
  ).take(widget.rounds).toList();
  int _i = 0, _clues = 1, _score = 0;
  bool? _right;
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _guess() {
    final ok = _ctl.text.trim().toLowerCase() == _round[_i].$1;
    setState(() {
      if (ok) {
        _right = true;
        _score += 5 - _clues;
      } else if (_clues < _round[_i].$2.length) {
        _clues++;
      } else {
        _right = false;
      }
      _ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final (word, clues) = _round[_i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(
          current: _i + 1,
          total: _round.length,
          trailing: '★ $_score',
        ),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  'A ${word.length}-letter word',
                  'Una palabra de ${word.length} letras',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              for (var k = 0; k < _clues; k++)
                OptionTile(label: '${k + 1}. ${clues[k]}', onTap: null),
              const SizedBox(height: 8),
              if (_right == null) ...[
                PrismTextField(
                  controller: _ctl,
                  hintText: tr(context, 'Your guess', 'Tu respuesta'),
                  onSubmitted: (_) => _guess(),
                ),
                GameActions(
                  children: [
                    if (_clues < clues.length)
                      PrismButton(
                        label: tr(context, 'Another clue', 'Otra pista'),
                        onPressed: () => setState(() => _clues++),
                      ),
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Guess', 'Adivinar'),
                      onPressed: _guess,
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  _right!
                      ? tr(context, '✓ Yes — "$word"!', '✓ ¡Sí: "$word"!')
                      : tr(context, 'It was "$word"', 'Era "$word"'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                GameActions(
                  children: [
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Next', 'Siguiente'),
                      onPressed: () {
                        if (_i + 1 >= _round.length) {
                          widget.session.finish(
                            GameOutcome(
                              score: _score,
                              max: _round.length * 4,
                              summary: tr(
                                context,
                                '$_score points',
                                '$_score puntos',
                              ),
                            ),
                          );
                        } else {
                          setState(() {
                            _i++;
                            _clues = 1;
                            _right = null;
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
// Word Search
// ---------------------------------------------------------------------------

class WordSearchGame extends StatefulWidget {
  const WordSearchGame({
    super.key,
    required this.session,
    required this.themes,
    this.size = 10,
  });
  final GameSession session;
  final Map<String, List<String>> themes;
  final int size;
  @override
  State<WordSearchGame> createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<WordSearchGame> {
  late final String _theme;
  late final List<List<String>> _grid;
  late final Map<String, List<(int, int)>> _placed;
  late final Set<String> _found = {
    for (final f in (widget.session.saved?['found'] as List?) ?? const []) '$f',
  };
  (int, int)? _start;

  @override
  void initState() {
    super.initState();
    final rng = widget.session.rng(10);
    final keys = widget.themes.keys.toList();
    _theme = keys[rng.nextInt(keys.length)];
    final n = widget.size;
    _grid = List.generate(n, (_) => List.filled(n, ''));
    _placed = {};
    const dirs = [(0, 1), (1, 0), (1, 1), (-1, 1)];
    for (final w in widget.themes[_theme]!.map((w) => w.toUpperCase())) {
      for (var attempt = 0; attempt < 200; attempt++) {
        final (dr, dc) = dirs[rng.nextInt(dirs.length)];
        final r0 = rng.nextInt(n), c0 = rng.nextInt(n);
        final cells = [
          for (var k = 0; k < w.length; k++) (r0 + dr * k, c0 + dc * k),
        ];
        if (cells.any((p) => p.$1 < 0 || p.$1 >= n || p.$2 < 0 || p.$2 >= n))
          continue;
        var ok = true;
        for (var k = 0; k < w.length; k++) {
          final cur = _grid[cells[k].$1][cells[k].$2];
          if (cur.isNotEmpty && cur != w[k]) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        for (var k = 0; k < w.length; k++) {
          _grid[cells[k].$1][cells[k].$2] = w[k];
        }
        _placed[w] = cells;
        break;
      }
    }
    const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (final row in _grid) {
      for (var c = 0; c < n; c++) {
        if (row[c].isEmpty) row[c] = abc[rng.nextInt(26)];
      }
    }
  }

  void _tap(int r, int c) {
    final s = _start;
    if (s == null) return setState(() => _start = (r, c));
    for (final e in _placed.entries) {
      if (_found.contains(e.key)) continue;
      final cells = e.value;
      if ((cells.first == s && cells.last == (r, c)) ||
          (cells.last == s && cells.first == (r, c))) {
        setState(() {
          _found.add(e.key);
          _start = null;
        });
        widget.session.save({'found': _found.toList()});
        if (_found.length == _placed.length) {
          widget.session.finish(
            GameOutcome(
              score: _found.length,
              max: _placed.length,
              summary: tr(
                context,
                'Found every $_theme word',
                'Todas las palabras de $_theme',
              ),
            ),
          );
        }
        return;
      }
    }
    setState(() => _start = (r, c));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foundCells = {for (final w in _found) ...?_placed[w]};
    final n = widget.size;
    return GamePanel(
      child: Column(
        children: [
          Text(
            _theme,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              context,
              'Tap the first letter of a word, then its last letter.',
              'Toca la primera letra de una palabra y luego la última.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.count(
              crossAxisCount: n,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var r = 0; r < n; r++)
                  for (var c = 0; c < n; c++)
                    Semantics(
                      button: true,
                      label: '${_grid[r][c]}, row ${r + 1}, column ${c + 1}',
                      child: GestureDetector(
                        onTap: () => _tap(r, c),
                        child: Container(
                          margin: const EdgeInsets.all(1.5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: prismCorners(context, 6),
                            color: _start == (r, c)
                                ? scheme.tertiary.withValues(alpha: 0.35)
                                : foundCells.contains((r, c))
                                ? scheme.primary.withValues(alpha: 0.25)
                                : scheme.surfaceContainerHighest,
                          ),
                          child: Text(
                            _grid[r][c],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final w in _placed.keys)
                Chip2(
                  _found.contains(w) ? '✓ ${w.toLowerCase()}' : w.toLowerCase(),
                  color: _found.contains(w) ? null : scheme.outline,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini Crossword (generated from a clue bank)
// ---------------------------------------------------------------------------

class _Slot {
  _Slot(this.word, this.r, this.c, this.across);
  final String word;
  final int r, c;
  final bool across;
  (int, int) cell(int k) => across ? (r, c + k) : (r + k, c);
}

class MiniCrosswordGame extends StatefulWidget {
  const MiniCrosswordGame({
    super.key,
    required this.session,
    required this.clues,
  });
  final GameSession session;
  final Map<String, String> clues;
  @override
  State<MiniCrosswordGame> createState() => _MiniCrosswordGameState();
}

class _MiniCrosswordGameState extends State<MiniCrosswordGame> {
  static const n = 9;
  late final List<_Slot> _slots;
  late final Map<(int, int), String> _answer;
  late final Map<(int, int), String> _typed = {
    for (final e
        in ((widget.session.saved?['typed'] as Map?) ?? const {}).entries)
      (
        int.parse('${e.key}'.split(',')[0]),
        int.parse('${e.key}'.split(',')[1]),
      ): '${e.value}',
  };
  (int, int)? _sel;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    final rng = widget.session.rng(11);
    final words = shuffled(widget.clues.keys.where((w) => w.length <= 6), rng);
    _slots = [];
    _answer = {};
    bool fits(String w, int r, int c, bool across) {
      var crosses = 0;
      for (var k = 0; k < w.length; k++) {
        final p = across ? (r, c + k) : (r + k, c);
        if (p.$1 < 0 || p.$2 < 0 || p.$1 >= n || p.$2 >= n) return false;
        final cur = _answer[p];
        if (cur != null && cur != w[k]) return false;
        if (cur != null) {
          crosses++;
          continue;
        }
        // No touching neighbours on the sides.
        final side = across
            ? [(p.$1 - 1, p.$2), (p.$1 + 1, p.$2)]
            : [(p.$1, p.$2 - 1), (p.$1, p.$2 + 1)];
        if (side.any(_answer.containsKey)) return false;
      }
      final before = across ? (r, c - 1) : (r - 1, c);
      final after = across ? (r, c + w.length) : (r + w.length, c);
      if (_answer.containsKey(before) || _answer.containsKey(after))
        return false;
      return _slots.isEmpty || crosses > 0;
    }

    void place(String w, int r, int c, bool across) {
      final s = _Slot(w, r, c, across);
      _slots.add(s);
      for (var k = 0; k < w.length; k++) {
        _answer[s.cell(k)] = w[k];
      }
    }

    place(words.first, 4, (n - words.first.length) ~/ 2, true);
    for (final w in words.skip(1)) {
      if (_slots.length >= 6) break;
      var done = false;
      for (final s in shuffled(_slots, rng)) {
        for (var i = 0; i < s.word.length && !done; i++) {
          for (var j = 0; j < w.length && !done; j++) {
            if (s.word[i] != w[j]) continue;
            final (pr, pc) = s.cell(i);
            final across = !s.across;
            final r = across ? pr : pr - j;
            final c = across ? pc - j : pc;
            if (fits(w, r, c, across)) {
              place(w, r, c, across);
              done = true;
            }
          }
        }
        if (done) break;
      }
    }
  }

  int? _number(_Slot s) {
    final starts = {for (final x in _slots) (x.r, x.c)}.toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    return starts.indexOf((s.r, s.c)) + 1;
  }

  void _type(String ch) {
    final s = _sel;
    if (s == null) return;
    setState(() {
      _typed[s] = ch;
      _checked = false;
      // Move to the next cell of a slot through this cell.
      final slot = _slots.firstWhere(
        (x) => List.generate(x.word.length, x.cell).contains(s),
      );
      final k = List.generate(slot.word.length, slot.cell).indexOf(s);
      if (k + 1 < slot.word.length) _sel = slot.cell(k + 1);
    });
    widget.session.save({
      'typed': {
        for (final e in _typed.entries) '${e.key.$1},${e.key.$2}': e.value,
      },
    });
    if (_answer.entries.every((e) => _typed[e.key] == e.value)) {
      widget.session.finish(
        GameOutcome(
          score: _slots.length,
          max: _slots.length,
          summary: tr(context, 'Crossword complete', 'Crucigrama completo'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _answer.keys.map((p) => p.$1);
    final cols = _answer.keys.map((p) => p.$2);
    final r0 = rows.reduce(math.min),
        r1 = rows.reduce(math.max),
        c0 = cols.reduce(math.min),
        c1 = cols.reduce(math.max);
    final numbers = {for (final s in _slots) (s.r, s.c): _number(s)};
    return GamePanel(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: (c1 - c0 + 1) / (r1 - r0 + 1),
            child: LayoutBuilder(
              builder: (context, box) {
                final cell = box.maxWidth / (c1 - c0 + 1);
                return Stack(
                  children: [
                    for (final p in _answer.keys)
                      Positioned(
                        left: (p.$2 - c0) * cell,
                        top: (p.$1 - r0) * cell,
                        width: cell,
                        height: cell,
                        child: GestureDetector(
                          onTap: () => setState(() => _sel = p),
                          child: Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: _sel == p
                                  ? scheme.primary.withValues(alpha: 0.25)
                                  : (_checked &&
                                            _typed[p] != null &&
                                            _typed[p] != _answer[p]
                                        ? scheme.error.withValues(alpha: 0.2)
                                        : scheme.surfaceContainerHighest),
                              border: Border.all(color: scheme.outline),
                              borderRadius: prismCorners(context, 4),
                            ),
                            child: Stack(
                              children: [
                                if (numbers[p] != null)
                                  Positioned(
                                    left: 2,
                                    top: 1,
                                    child: Text(
                                      '${numbers[p]}',
                                      style: TextStyle(fontSize: cell * 0.22),
                                    ),
                                  ),
                                Center(
                                  child: Text(
                                    (_typed[p] ?? '').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: cell * 0.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          for (final across in [true, false]) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                across
                    ? tr(context, 'Across', 'Horizontales')
                    : tr(context, 'Down', 'Verticales'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final s in _slots.where((s) => s.across == across))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${_number(s)}. ${widget.clues[s.word]} (${s.word.length})',
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          GameKeyboard(
            onKey: _type,
            onBack: () =>
                _sel == null ? null : setState(() => _typed.remove(_sel)),
          ),
          GameActions(
            children: [
              PrismButton(
                label: tr(context, 'Check', 'Comprobar'),
                onPressed: () => setState(() => _checked = true),
              ),
              PrismButton(
                label: tr(context, 'Reveal a letter', 'Revelar una letra'),
                onPressed: () {
                  final missing = _answer.entries
                      .where((e) => _typed[e.key] != e.value)
                      .toList();
                  if (missing.isNotEmpty) {
                    _sel = missing.first.key;
                    _type(missing.first.value);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
