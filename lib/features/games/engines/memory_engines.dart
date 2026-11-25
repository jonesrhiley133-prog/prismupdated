import 'dart:math' as math;

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/engines/grid_engines.dart'
    show CellGrid;
import 'package:prism_plurality/features/games/engines/tone_player.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const memoryEmojis = [
  '🍎',
  '🌙',
  '⭐',
  '🌸',
  '🐢',
  '🍄',
  '🎈',
  '🦋',
  '🍩',
  '🌈',
  '🐝',
  '🎵',
  '🧸',
  '🍀',
  '🐙',
  '🍓',
  '☂️',
  '🔑',
  '🕯️',
  '🧩',
  '🪴',
  '🐳',
  '🍪',
  '🎀',
];

// ---------------------------------------------------------------------------
// Memory Match (also custom card sets and Sound Match)
// ---------------------------------------------------------------------------

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({
    super.key,
    required this.session,
    this.pairs,
    this.sounds = false,
  });
  final GameSession session;

  /// Custom pairs (front, match). Default: emoji pairs.
  final List<(String, String)>? pairs;

  /// Sound Match: cards play tones; match equal tones.
  final bool sounds;
  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  late int _pairsCount = widget.sounds ? 6 : 8;
  late List<(int, String)> _cards; // (pair id, face)
  final Set<int> _open = {};
  final Set<int> _done = {};
  int _flips = 0;
  bool _busy = false;
  final _tone = TonePlayer();

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _tone.dispose();
    super.dispose();
  }

  void _deal() {
    final rng = widget.session.rng(40 + _pairsCount);
    final custom = widget.pairs;
    final List<(int, String)> cards;
    if (custom != null && custom.isNotEmpty) {
      final picked = shuffled(
        List.generate(custom.length, (i) => i),
        rng,
      ).take(_pairsCount).toList();
      cards = [
        for (final i in picked) ...[(i, custom[i].$1), (i, custom[i].$2)],
      ];
    } else {
      final faces = shuffled(memoryEmojis, rng).take(_pairsCount).toList();
      cards = [
        for (var i = 0; i < faces.length; i++) ...[
          (i, faces[i]),
          (i, faces[i]),
        ],
      ];
    }
    _cards = shuffled(cards, rng);
    _open.clear();
    _done.clear();
    _flips = 0;
  }

  Future<void> _flip(int i) async {
    if (_busy || _open.contains(i) || _done.contains(i)) return;
    if (widget.sounds)
      _tone.play(TonePlayer.scale[_cards[i].$1 % TonePlayer.scale.length]);
    setState(() {
      _open.add(i);
      _flips++;
    });
    if (_open.length < 2) return;
    final [a, b] = _open.toList();
    if (_cards[a].$1 == _cards[b].$1) {
      setState(() {
        _done.addAll(_open);
        _open.clear();
      });
      if (_done.length == _cards.length) {
        widget.session.finish(
          GameOutcome(
            score: math.max(1, _cards.length * 2 - _flips),
            summary: tr(
              context,
              'All pairs in $_flips flips',
              'Todas las parejas en $_flips giros',
            ),
          ),
        );
      }
    } else {
      _busy = true;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _open.clear();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cols = _cards.length <= 12 ? 3 : 4;
    return GamePanel(
      child: Column(
        children: [
          if (widget.pairs == null && !widget.sounds)
            PrismSegmentedControl<int>(
              segments: [
                PrismSegment(
                  value: 6,
                  label: tr(context, '6 pairs', '6 parejas'),
                ),
                PrismSegment(
                  value: 8,
                  label: tr(context, '8 pairs', '8 parejas'),
                ),
                PrismSegment(
                  value: 10,
                  label: tr(context, '10 pairs', '10 parejas'),
                ),
              ],
              selected: _pairsCount,
              onChanged: (v) => setState(() {
                _pairsCount = v;
                _deal();
              }),
            ),
          if (widget.sounds)
            Text(
              tr(
                context,
                'Each card plays a note. Find the pairs that sound the same.',
                'Cada carta suena con una nota. Encuentra las parejas que suenan igual.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 10),
          CellGrid(
            rows: (_cards.length / cols).ceil(),
            cols: cols,
            gap: 8,
            cell: (r, c) {
              final i = r * cols + c;
              if (i >= _cards.length) return const SizedBox.shrink();
              final up = _open.contains(i) || _done.contains(i);
              final face = _cards[i].$2;
              return Semantics(
                button: true,
                label: up
                    ? (widget.sounds ? 'note ${_cards[i].$1 + 1}' : face)
                    : tr(context, 'Hidden card', 'Carta oculta'),
                child: GestureDetector(
                  onTap: () => _flip(i),
                  child: AnimatedContainer(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _done.contains(i)
                          ? scheme.primary.withValues(alpha: 0.18)
                          : up
                          ? scheme.surfaceContainerHighest
                          : scheme.primary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: up
                        ? (widget.sounds
                              ? Icon(
                                  PhosphorIcons.musicNote(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  color: gameplayColors[_cards[i].$1 % 6].$1,
                                )
                              : Text(
                                  face,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: face.characters.length > 2
                                        ? 14
                                        : 30,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ))
                        : Icon(
                            PhosphorIcons.sparkle(),
                            color: scheme.onPrimary,
                          ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(tr(context, 'Flips: $_flips', 'Giros: $_flips')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Study then answer: Picture Recall · Object Detective · Quick Observation ·
// Shopping List · Number Memory · Pattern Memory
// ---------------------------------------------------------------------------

enum RecallKind { picture, missing, observe, shopping }

class RecallGame extends StatefulWidget {
  const RecallGame({
    super.key,
    required this.session,
    required this.kind,
    this.rounds = 5,
  });
  final GameSession session;
  final RecallKind kind;
  final int rounds;
  @override
  State<RecallGame> createState() => _RecallGameState();
}

class _RecallGameState extends State<RecallGame> {
  late final math.Random _rng = widget.session.rng(50);
  static const shopping = [
    'milk',
    'eggs',
    'bread',
    'apples',
    'rice',
    'tea',
    'honey',
    'carrots',
    'cheese',
    'pasta',
    'lemons',
    'soap',
    'oats',
    'jam',
    'beans',
    'butter',
    'flour',
    'grapes',
  ];
  int _round = 0, _score = 0;
  bool _studying = true;
  late List<String> _items;
  late (int, List<String>) _question; // kind, options
  String _target = '';
  String? _picked;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final n = 4 + _round;
    switch (widget.kind) {
      case RecallKind.shopping:
        _items = shuffled(shopping, _rng).take(n).toList();
        final absent = shuffled(
          shopping.where((s) => !_items.contains(s)),
          _rng,
        ).take(3).toList();
        final present = _items[_rng.nextInt(_items.length)];
        _question = (0, shuffled([present, ...absent], _rng));
        _answer = present;
      case RecallKind.picture:
        _items = shuffled(memoryEmojis, _rng).take(n + 2).toList();
        final present = _items[_rng.nextInt(_items.length)];
        final absent = shuffled(
          memoryEmojis.where((s) => !_items.contains(s)),
          _rng,
        ).take(3).toList();
        _question = (1, shuffled([present, ...absent], _rng));
        _answer = present;
      case RecallKind.missing:
        _items = shuffled(memoryEmojis, _rng).take(n + 1).toList();
        final gone = _items[_rng.nextInt(_items.length)];
        _missingShown = [..._items]..remove(gone);
        final decoys = shuffled(_missingShown, _rng).take(3).toList();
        _question = (2, shuffled([gone, ...decoys], _rng));
        _answer = gone;
      case RecallKind.observe:
        final kinds = shuffled(memoryEmojis.take(8), _rng).take(3).toList();
        _items = [
          for (var i = 0; i < n + 4; i++) kinds[_rng.nextInt(kinds.length)],
        ]..shuffle(_rng);
        final target = kinds[_rng.nextInt(kinds.length)];
        final count = _items.where((e) => e == target).length;
        _target = target;
        _question = (
          3,
          shuffled(
            {
              '$count',
              '${count + 1}',
              '${math.max(0, count - 1)}',
              '${count + 2}',
            }.toList(),
            _rng,
          ),
        );
        _answer = '$count';
    }
    _studying = true;
    _picked = null;
  }

  late String _answer;
  List<String> _missingShown = const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final study = widget.kind == RecallKind.shopping
        ? Column(
            children: [
              for (final s in _items)
                Text('• $s', style: theme.textTheme.titleMedium),
            ],
          )
        : Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in _items)
                Text(e, style: const TextStyle(fontSize: 36)),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(
          current: _round + 1,
          total: widget.rounds,
          trailing: '★ $_score',
        ),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_studying) ...[
                Text(
                  tr(
                    context,
                    'Take your time and remember these. Tap "Ready" when you are.',
                    'Tómate tu tiempo y recuérdalos. Pulsa "Listo" cuando quieras.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                study,
                if (widget.session.timer)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GameTimer(
                      key: ValueKey(_round),
                      seconds: 6,
                      onDone: () => setState(() => _studying = false),
                    ),
                  ),
                GameActions(
                  children: [
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: tr(context, 'Ready', 'Listo'),
                      onPressed: () => setState(() => _studying = false),
                    ),
                  ],
                ),
              ] else ...[
                if (widget.kind == RecallKind.missing) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final e in _missingShown)
                        Text(e, style: const TextStyle(fontSize: 36)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                GamePrompt(switch (_question.$1) {
                  0 => tr(
                    context,
                    'Which was on the list?',
                    '¿Cuál estaba en la lista?',
                  ),
                  1 => tr(context, 'Which one did you see?', '¿Cuál viste?'),
                  2 => tr(
                    context,
                    'Which object disappeared?',
                    '¿Qué objeto desapareció?',
                  ),
                  _ => tr(
                    context,
                    'How many $_target were there?',
                    '¿Cuántos $_target había?',
                  ),
                }),
                const SizedBox(height: 10),
                for (final o in _question.$2)
                  OptionTile(
                    label: o,
                    state: _picked == null
                        ? null
                        : (o == _answer ? true : (o == _picked ? false : null)),
                    onTap: _picked != null
                        ? null
                        : () => setState(() {
                            _picked = o;
                            if (o == _answer) _score++;
                          }),
                  ),
                if (_picked != null)
                  GameActions(
                    children: [
                      PrismButton(
                        tone: PrismButtonTone.filled,
                        label: tr(context, 'Next', 'Siguiente'),
                        onPressed: () {
                          if (_round + 1 >= widget.rounds) {
                            widget.session.finish(
                              GameOutcome(
                                score: _score,
                                max: widget.rounds,
                                summary: '$_score / ${widget.rounds}',
                              ),
                            );
                          } else {
                            setState(() {
                              _round++;
                              _newRound();
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

class NumberMemoryGame extends StatefulWidget {
  const NumberMemoryGame({super.key, required this.session});
  final GameSession session;
  @override
  State<NumberMemoryGame> createState() => _NumberMemoryGameState();
}

class _NumberMemoryGameState extends State<NumberMemoryGame> {
  late final math.Random _rng = widget.session.rng(51);
  int _len = 3;
  late String _num = _make();
  bool _studying = true;
  final _ctl = TextEditingController();

  String _make() => List.generate(
    _len,
    (i) => i == 0 ? _rng.nextInt(9) + 1 : _rng.nextInt(10),
  ).join();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        children: [
          Text(
            tr(context, '$_len digits', '$_len cifras'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          if (_studying) ...[
            Text(
              _num.split('').join(' '),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            if (widget.session.timer)
              GameTimer(
                key: ValueKey(_len),
                seconds: 2 + _len ~/ 2,
                onDone: () => setState(() => _studying = false),
              ),
            GameActions(
              children: [
                PrismButton(
                  tone: PrismButtonTone.filled,
                  label: tr(context, 'Hide & answer', 'Ocultar y responder'),
                  onPressed: () => setState(() => _studying = false),
                ),
              ],
            ),
          ] else ...[
            PrismTextField(
              controller: _ctl,
              keyboardType: TextInputType.number,
              hintText: tr(context, 'Type the number', 'Escribe el número'),
              autofocus: true,
              onSubmitted: (_) => _check(),
            ),
            GameActions(
              children: [
                PrismButton(
                  tone: PrismButtonTone.filled,
                  label: tr(context, 'Check', 'Comprobar'),
                  onPressed: _check,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _check() {
    if (_ctl.text.trim() == _num) {
      setState(() {
        _len++;
        _num = _make();
        _studying = true;
        _ctl.clear();
      });
    } else {
      widget.session.finish(
        GameOutcome(
          score: _len - 1,
          summary: tr(
            context,
            'Remembered ${_len - 1} digits (it was $_num)',
            'Recordaste ${_len - 1} cifras (era $_num)',
          ),
        ),
      );
    }
  }
}

class PatternMemoryGame extends StatefulWidget {
  const PatternMemoryGame({super.key, required this.session});
  final GameSession session;
  @override
  State<PatternMemoryGame> createState() => _PatternMemoryGameState();
}

class _PatternMemoryGameState extends State<PatternMemoryGame> {
  late final math.Random _rng = widget.session.rng(52);
  int _level = 3;
  late Set<int> _target = _make();
  final Set<int> _picked = {};
  bool _studying = true;

  int get _n => _level < 6 ? 4 : 5;
  Set<int> _make() {
    final s = <int>{};
    while (s.length < _level) {
      s.add(_rng.nextInt(_n * _n));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          Text(
            _studying
                ? tr(
                    context,
                    'Remember the lit squares',
                    'Recuerda las casillas iluminadas',
                  )
                : tr(
                    context,
                    'Tap the squares that were lit (${_picked.length}/$_level)',
                    'Toca las casillas iluminadas (${_picked.length}/$_level)',
                  ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          CellGrid(
            rows: _n,
            cols: _n,
            gap: 6,
            cell: (r, c) {
              final i = r * _n + c;
              final lit = _studying ? _target.contains(i) : _picked.contains(i);
              return Semantics(
                button: !_studying,
                label: lit ? 'lit' : 'dark',
                child: GestureDetector(
                  onTap: _studying
                      ? null
                      : () {
                          if (!_target.contains(i)) {
                            widget.session.finish(
                              GameOutcome(
                                score: _level - 1,
                                summary: tr(
                                  context,
                                  'Reached level ${_level - 2}',
                                  'Llegaste al nivel ${_level - 2}',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _picked.add(i));
                          if (_picked.length == _target.length) {
                            setState(() {
                              _level++;
                              _target = _make();
                              _picked.clear();
                              _studying = true;
                            });
                          }
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: lit
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_studying)
            GameActions(
              children: [
                PrismButton(
                  tone: PrismButtonTone.filled,
                  label: tr(context, 'Ready', 'Listo'),
                  onPressed: () => setState(() => _studying = false),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
