import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A square grid of tappable cells.
class CellGrid extends StatelessWidget {
  const CellGrid({super.key, required this.rows, required this.cols, required this.cell, this.gap = 2});
  final int rows;
  final int cols;
  final Widget Function(int r, int c) cell;
  final double gap;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: cols / rows,
    child: Column(
      children: [
        for (var r = 0; r < rows; r++)
          Expanded(
            child: Row(children: [for (var c = 0; c < cols; c++) Expanded(child: Padding(padding: EdgeInsets.all(gap / 2), child: cell(r, c)))]),
          ),
      ],
    ),
  );
}

Widget _box(BuildContext context, {required Widget child, Color? color, VoidCallback? onTap, String? label, bool selected = false, double radius = 6}) {
  final scheme = Theme.of(context).colorScheme;
  return Semantics(
    button: onTap != null,
    label: label,
    selected: selected,
    child: Material(
      color: color ?? scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 0.6)),
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: Center(child: child)),
    ),
  );
}

/// Arrow pad for games that move (mazes, merges) — swipes and keyboard
/// arrows work too.
class ArrowPad extends StatelessWidget {
  const ArrowPad({super.key, required this.onMove});
  final void Function(int dr, int dc) onMove;
  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, int dr, int dc, String label) => Padding(
      padding: const EdgeInsets.all(3),
      child: PrismIconButton(icon: i, tooltip: label, onPressed: () => onMove(dr, dc)),
    );
    return Column(
      children: [
        b(PhosphorIcons.arrowUp(), -1, 0, tr(context, 'Up', 'Arriba')),
        Row(mainAxisSize: MainAxisSize.min, children: [b(PhosphorIcons.arrowLeft(), 0, -1, tr(context, 'Left', 'Izquierda')), const SizedBox(width: 44), b(PhosphorIcons.arrowRight(), 0, 1, tr(context, 'Right', 'Derecha'))]),
        b(PhosphorIcons.arrowDown(), 1, 0, tr(context, 'Down', 'Abajo')),
      ],
    );
  }
}

/// Swipe + arrow-key input around [child].
class MoveInput extends StatelessWidget {
  const MoveInput({super.key, required this.child, required this.onMove});
  final Widget child;
  final void Function(int dr, int dc) onMove;
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, e) {
      if (e is! KeyDownEvent) return KeyEventResult.ignored;
      final k = e.logicalKey;
      if (k == LogicalKeyboardKey.arrowUp) onMove(-1, 0);
      if (k == LogicalKeyboardKey.arrowDown) onMove(1, 0);
      if (k == LogicalKeyboardKey.arrowLeft) onMove(0, -1);
      if (k == LogicalKeyboardKey.arrowRight) onMove(0, 1);
      return KeyEventResult.handled;
    },
    child: GestureDetector(
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        if (v.distance < 200) return;
        if (v.dx.abs() > v.dy.abs()) {
          onMove(0, v.dx > 0 ? 1 : -1);
        } else {
          onMove(v.dy > 0 ? 1 : -1, 0);
        }
      },
      child: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Sudoku (9×9, 6×6, 4×4)
// ---------------------------------------------------------------------------

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key, required this.session, this.size = 9});
  final GameSession session;
  final int size;
  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  late final int n = widget.size;
  late final int br = n == 6 ? 2 : (n == 4 ? 2 : 3); // box rows
  late final int bc = n == 6 ? 3 : (n == 4 ? 2 : 3); // box cols
  late List<int> _solution;
  late List<int> _given;
  late List<int> _board;
  late List<Set<int>> _notes;
  int? _sel;
  bool _notesMode = false;
  int _mistakes = 0;
  final List<(int, int)> _undo = [];

  @override
  void initState() {
    super.initState();
    final saved = widget.session.saved;
    if (saved != null && saved['solution'] is List) {
      _solution = [for (final v in saved['solution'] as List) (v as num).toInt()];
      _given = [for (final v in saved['given'] as List) (v as num).toInt()];
      _board = [for (final v in saved['board'] as List) (v as num).toInt()];
    } else {
      _generate();
    }
    _notes = List.generate(n * n, (_) => <int>{});
  }

  bool _ok(List<int> g, int i, int v) {
    final r = i ~/ n, c = i % n;
    for (var k = 0; k < n; k++) {
      if (g[r * n + k] == v || g[k * n + c] == v) return false;
    }
    final r0 = r ~/ br * br, c0 = c ~/ bc * bc;
    for (var a = 0; a < br; a++) {
      for (var b = 0; b < bc; b++) {
        if (g[(r0 + a) * n + c0 + b] == v) return false;
      }
    }
    return true;
  }

  bool _fill(List<int> g, math.Random rng) {
    final i = g.indexOf(0);
    if (i < 0) return true;
    for (final v in shuffled(List.generate(n, (k) => k + 1), rng)) {
      if (_ok(g, i, v)) {
        g[i] = v;
        if (_fill(g, rng)) return true;
        g[i] = 0;
      }
    }
    return false;
  }

  int _count(List<int> g, [int limit = 2]) {
    final i = g.indexOf(0);
    if (i < 0) return 1;
    var total = 0;
    for (var v = 1; v <= n; v++) {
      if (_ok(g, i, v)) {
        g[i] = v;
        total += _count(g, limit - total);
        g[i] = 0;
        if (total >= limit) break;
      }
    }
    return total;
  }

  void _generate() {
    final rng = widget.session.rng(20);
    final g = List.filled(n * n, 0);
    _fill(g, rng);
    _solution = [...g];
    final target = switch (n) { 4 => 9, 6 => 18, _ => 46 };
    var removed = 0;
    for (final i in shuffled(List.generate(n * n, (k) => k), rng)) {
      if (removed >= target) break;
      final keep = g[i];
      g[i] = 0;
      if (_count([...g]) != 1) {
        g[i] = keep;
      } else {
        removed++;
      }
    }
    _given = [...g];
    _board = [...g];
  }

  void _input(int v) {
    final i = _sel;
    if (i == null || _given[i] != 0) return;
    setState(() {
      if (_notesMode && v != 0) {
        _notes[i].contains(v) ? _notes[i].remove(v) : _notes[i].add(v);
        return;
      }
      _undo.add((i, _board[i]));
      _board[i] = v;
      _notes[i].clear();
      if (v != 0 && v != _solution[i]) _mistakes++;
    });
    widget.session.save({'solution': _solution, 'given': _given, 'board': _board});
    if (!_board.contains(0) && List.generate(n * n, (k) => _board[k] == _solution[k]).every((b) => b)) {
      widget.session.finish(GameOutcome(score: math.max(1, 10 - _mistakes), max: 10, summary: tr(context, 'Solved with $_mistakes slips', 'Resuelto con $_mistakes fallos')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selVal = _sel == null ? 0 : _board[_sel!];
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          CellGrid(
            rows: n,
            cols: n,
            gap: 0,
            cell: (r, c) {
              final i = r * n + c;
              final v = _board[i];
              final wrong = v != 0 && v != _solution[i];
              final related = _sel != null && (_sel! ~/ n == r || _sel! % n == c);
              return GestureDetector(
                onTap: () => setState(() => _sel = i),
                child: Semantics(
                  button: true,
                  label: 'Row ${r + 1}, column ${c + 1}, ${v == 0 ? 'empty' : '$v'}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: _sel == i
                          ? scheme.primary.withValues(alpha: 0.3)
                          : (v != 0 && v == selVal)
                          ? scheme.primary.withValues(alpha: 0.14)
                          : related
                          ? scheme.surfaceContainerHigh
                          : scheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(color: scheme.outline, width: r % br == 0 ? 1.8 : 0.4),
                        left: BorderSide(color: scheme.outline, width: c % bc == 0 ? 1.8 : 0.4),
                        right: BorderSide(color: scheme.outline, width: c == n - 1 ? 1.8 : 0),
                        bottom: BorderSide(color: scheme.outline, width: r == n - 1 ? 1.8 : 0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: v != 0
                        ? Text('$v', style: TextStyle(fontSize: n == 9 ? 18 : 22, fontWeight: _given[i] != 0 ? FontWeight.w800 : FontWeight.w500, color: wrong ? scheme.error : (_given[i] != 0 ? scheme.onSurface : scheme.primary), decoration: wrong ? TextDecoration.underline : null))
                        : _notes[i].isEmpty
                        ? null
                        : Text((_notes[i].toList()..sort()).join(), style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var v = 1; v <= n; v++) SizedBox(width: 40, height: 44, child: _box(context, child: Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), onTap: () => _input(v), label: '$v')),
            ],
          ),
          GameActions(children: [
            PrismButton(label: tr(context, 'Erase', 'Borrar'), icon: PhosphorIcons.eraser(), onPressed: () => _input(0)),
            PrismButton(label: _notesMode ? tr(context, 'Notes: on', 'Notas: sí') : tr(context, 'Notes: off', 'Notas: no'), icon: PhosphorIcons.pencilSimple(), onPressed: () => setState(() => _notesMode = !_notesMode)),
            PrismButton(label: tr(context, 'Undo', 'Deshacer'), icon: PhosphorIcons.arrowUUpLeft(), onPressed: _undo.isEmpty ? () {} : () => setState(() {
              final (i, v) = _undo.removeLast();
              _board[i] = v;
            })),
            PrismButton(label: tr(context, 'Hint', 'Pista'), icon: PhosphorIcons.lightbulb(), onPressed: () {
              final empty = [for (var i = 0; i < n * n; i++) if (_board[i] != _solution[i]) i];
              if (empty.isEmpty) return;
              _sel = empty.first;
              _mistakes++;
              _input(_solution[empty.first]);
            }),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nonograms
// ---------------------------------------------------------------------------

/// Small pixel pictures (rows of # and .).
const nonogramPictures = <String, List<String>>{
  'Heart': ['.##.##.', '#######', '#######', '.#####.', '..###..', '...#...'],
  'Cat': ['#...#', '##.##', '#####', '#.#.#', '#####', '.###.'],
  'House': ['...#...', '..###..', '.#####.', '#######', '.##.##.', '.##.##.', '.#####.'],
  'Tree': ['..#..', '.###.', '#####', '.###.', '#####', '..#..', '..#..'],
  'Star': ['...#...', '..###..', '#######', '.#####.', '..###..', '.##.##.', '##...##'],
  'Mug': ['#####.', '#####.', '######', '#####.#', '######', '#####.'],
  'Moon': ['..###.', '.##...', '##....', '##....', '.##...', '..###.'],
  'Flower': ['.#.#.', '#####', '.###.', '..#..', '#.#.#', '.###.'],
  'Key': ['.###......', '#...#.....', '#...######', '#...#.#.#.', '.###......'],
  'Fish': ['...###..#', '.######.#', '#.#######', '.######.#', '...###..#'],
};

class NonogramGame extends StatefulWidget {
  const NonogramGame({super.key, required this.session});
  final GameSession session;
  @override
  State<NonogramGame> createState() => _NonogramGameState();
}

class _NonogramGameState extends State<NonogramGame> {
  late final String _name;
  late final List<String> _pic;
  late final int rows, cols;
  late final List<int> _cells; // 0 empty, 1 filled, 2 crossed
  bool _cross = false;

  @override
  void initState() {
    super.initState();
    final keys = nonogramPictures.keys.toList();
    _name = keys[widget.session.rng(21).nextInt(keys.length)];
    final raw = nonogramPictures[_name]!;
    cols = raw.map((r) => r.length).reduce(math.max);
    _pic = [for (final r in raw) r.padRight(cols, '.')];
    rows = _pic.length;
    final saved = widget.session.saved?['cells'] as List?;
    _cells = saved != null && saved.length == rows * cols ? [for (final v in saved) (v as num).toInt()] : List.filled(rows * cols, 0);
  }

  List<int> _clue(String line) {
    final out = <int>[];
    var run = 0;
    for (final ch in line.split('')) {
      if (ch == '#') {
        run++;
      } else if (run > 0) {
        out.add(run);
        run = 0;
      }
    }
    if (run > 0) out.add(run);
    return out.isEmpty ? [0] : out;
  }

  void _tap(int r, int c) {
    final i = r * cols + c;
    setState(() => _cells[i] = _cells[i] == 0 ? (_cross ? 2 : 1) : 0);
    widget.session.save({'cells': _cells});
    final solved = List.generate(rows * cols, (k) => (_cells[k] == 1) == (_pic[k ~/ cols][k % cols] == '#')).every((b) => b);
    if (solved) widget.session.finish(GameOutcome(score: 1, max: 1, summary: tr(context, 'Revealed: $_name', 'Revelado: $_name')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowClues = [for (final r in _pic) _clue(r).join(' ')];
    final colClues = [for (var c = 0; c < cols; c++) _clue([for (final r in _pic) r[c]].join())];
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(tr(context, 'Numbers show runs of filled squares in each row and column.', 'Los números indican los bloques de casillas rellenas de cada fila y columna.'), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, box) {
            final clueW = 56.0;
            final cell = math.min(38.0, (box.maxWidth - clueW) / cols);
            return Column(
              children: [
                Row(children: [
                  SizedBox(width: clueW),
                  for (final cc in colClues) SizedBox(width: cell, child: Text(cc.join('\n'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.1, fontWeight: FontWeight.w700))),
                ]),
                for (var r = 0; r < rows; r++)
                  Row(children: [
                    SizedBox(width: clueW, child: Text(rowClues[r], textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 4),
                    for (var c = 0; c < cols; c++)
                      SizedBox(
                        width: cell - 4 / cols,
                        height: cell,
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: _box(
                            context,
                            radius: 3,
                            color: _cells[r * cols + c] == 1 ? scheme.primary : null,
                            label: 'Row ${r + 1}, column ${c + 1}',
                            onTap: () => _tap(r, c),
                            child: _cells[r * cols + c] == 2 ? Icon(PhosphorIcons.x(), size: cell * 0.5, color: scheme.onSurfaceVariant) : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ]),
              ],
            );
          }),
          const SizedBox(height: 8),
          PrismSegmentedControl<bool>(
            segments: [PrismSegment(value: false, label: tr(context, 'Fill', 'Rellenar')), PrismSegment(value: true, label: tr(context, 'Mark ✗', 'Marcar ✗'))],
            selected: _cross,
            onChanged: (v) => setState(() => _cross = v),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sliding puzzle
// ---------------------------------------------------------------------------

class SlidingPuzzleGame extends StatefulWidget {
  const SlidingPuzzleGame({super.key, required this.session, this.size = 3});
  final GameSession session;
  final int size;
  @override
  State<SlidingPuzzleGame> createState() => _SlidingPuzzleGameState();
}

class _SlidingPuzzleGameState extends State<SlidingPuzzleGame> {
  late int n = widget.size;
  late List<int> _tiles;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final rng = widget.session.rng(22 + n);
    _tiles = List.generate(n * n, (i) => (i + 1) % (n * n));
    var blank = n * n - 1;
    for (var k = 0; k < 200 * n; k++) {
      final opts = [for (final d in [-1, 1, -n, n]) blank + d].where((j) => j >= 0 && j < n * n && ((j - blank).abs() == n || j ~/ n == blank ~/ n)).toList();
      final j = opts[rng.nextInt(opts.length)];
      _tiles[blank] = _tiles[j];
      _tiles[j] = 0;
      blank = j;
    }
    _moves = 0;
  }

  void _tap(int i) {
    final b = _tiles.indexOf(0);
    if (!((i - b).abs() == n || ((i - b).abs() == 1 && i ~/ n == b ~/ n))) return;
    setState(() {
      _tiles[b] = _tiles[i];
      _tiles[i] = 0;
      _moves++;
    });
    if (List.generate(n * n - 1, (k) => _tiles[k] == k + 1).every((x) => x)) {
      widget.session.finish(GameOutcome(score: math.max(1, 100 - _moves), summary: tr(context, 'Solved in $_moves moves', 'Resuelto en $_moves movimientos')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          PrismSegmentedControl<int>(
            segments: const [PrismSegment(value: 3, label: '3×3'), PrismSegment(value: 4, label: '4×4')],
            selected: n,
            onChanged: (v) => setState(() {
              n = v;
              _shuffle();
            }),
          ),
          const SizedBox(height: 12),
          CellGrid(
            rows: n,
            cols: n,
            gap: 4,
            cell: (r, c) {
              final i = r * n + c;
              final t = _tiles[i];
              if (t == 0) return const SizedBox.shrink();
              return _box(context, color: scheme.primary.withValues(alpha: 0.18 + 0.5 * t / (n * n)), radius: 10, onTap: () => _tap(i), label: 'Tile $t', child: Text('$t', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)));
            },
          ),
          const SizedBox(height: 8),
          Text(tr(context, 'Moves: $_moves', 'Movimientos: $_moves')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini maze
// ---------------------------------------------------------------------------

class MazeGame extends StatefulWidget {
  const MazeGame({super.key, required this.session});
  final GameSession session;
  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  int n = 8;
  late List<Set<int>> _open; // per cell: open directions 0 up 1 right 2 down 3 left
  int _pos = 0;
  int _steps = 0;
  final Set<int> _trail = {0};

  @override
  void initState() {
    super.initState();
    _make();
  }

  void _make() {
    final rng = widget.session.rng(23 + n);
    _open = List.generate(n * n, (_) => <int>{});
    final seen = {0};
    final stack = [0];
    while (stack.isNotEmpty) {
      final cur = stack.last;
      final r = cur ~/ n, c = cur % n;
      final nb = <(int, int, int)>[
        if (r > 0 && !seen.contains(cur - n)) (cur - n, 0, 2),
        if (c < n - 1 && !seen.contains(cur + 1)) (cur + 1, 1, 3),
        if (r < n - 1 && !seen.contains(cur + n)) (cur + n, 2, 0),
        if (c > 0 && !seen.contains(cur - 1)) (cur - 1, 3, 1),
      ];
      if (nb.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (nx, d, back) = nb[rng.nextInt(nb.length)];
      _open[cur].add(d);
      _open[nx].add(back);
      seen.add(nx);
      stack.add(nx);
    }
    _pos = 0;
    _steps = 0;
    _trail
      ..clear()
      ..add(0);
  }

  void _move(int dr, int dc) {
    final d = dr == -1 ? 0 : dc == 1 ? 1 : dr == 1 ? 2 : 3;
    if (!_open[_pos].contains(d)) return;
    setState(() {
      _pos += dr * n + dc;
      _steps++;
      _trail.add(_pos);
    });
    if (_pos == n * n - 1) {
      widget.session.finish(GameOutcome(score: n, summary: tr(context, 'Out of the ${n}×$n maze in $_steps steps', 'Fuera del laberinto ${n}×$n en $_steps pasos')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          PrismSegmentedControl<int>(
            segments: [PrismSegment(value: 6, label: tr(context, 'Small', 'Pequeño')), PrismSegment(value: 8, label: tr(context, 'Medium', 'Mediano')), PrismSegment(value: 12, label: tr(context, 'Large', 'Grande'))],
            selected: n,
            onChanged: (v) => setState(() {
              n = v;
              _make();
            }),
          ),
          const SizedBox(height: 10),
          MoveInput(
            onMove: _move,
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(painter: _MazePainter(n, _open, _pos, _trail, scheme)),
            ),
          ),
          const SizedBox(height: 10),
          ArrowPad(onMove: _move),
          Text(tr(context, 'Reach the bottom-right corner 🏁. Swipe, use arrow keys or the pad.', 'Llega a la esquina inferior derecha 🏁. Desliza, usa las flechas o los botones.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter(this.n, this.open, this.pos, this.trail, this.scheme);
  final int n;
  final List<Set<int>> open;
  final int pos;
  final Set<int> trail;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / n;
    final wall = Paint()
      ..color = scheme.onSurface
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final t in trail) {
      canvas.drawRect(Rect.fromLTWH((t % n) * s + 2, (t ~/ n) * s + 2, s - 4, s - 4), Paint()..color = scheme.primary.withValues(alpha: 0.12));
    }
    canvas.drawRect(Rect.fromLTWH((n - 1) * s + 3, (n - 1) * s + 3, s - 6, s - 6), Paint()..color = scheme.tertiary.withValues(alpha: 0.5));
    for (var i = 0; i < n * n; i++) {
      final x = (i % n) * s, y = (i ~/ n) * s;
      if (!open[i].contains(0)) canvas.drawLine(Offset(x, y), Offset(x + s, y), wall);
      if (!open[i].contains(1)) canvas.drawLine(Offset(x + s, y), Offset(x + s, y + s), wall);
      if (!open[i].contains(2)) canvas.drawLine(Offset(x, y + s), Offset(x + s, y + s), wall);
      if (!open[i].contains(3)) canvas.drawLine(Offset(x, y), Offset(x, y + s), wall);
    }
    canvas.drawCircle(Offset((pos % n) * s + s / 2, (pos ~/ n) * s + s / 2), s * 0.3, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(_MazePainter o) => true;
}

// ---------------------------------------------------------------------------
// Number Merge (2048-style)
// ---------------------------------------------------------------------------

class MergeGame extends StatefulWidget {
  const MergeGame({super.key, required this.session});
  final GameSession session;
  @override
  State<MergeGame> createState() => _MergeGameState();
}

class _MergeGameState extends State<MergeGame> {
  static const n = 4;
  late List<int> _g;
  int _score = 0;
  late final math.Random _rng = widget.session.rng(24);

  @override
  void initState() {
    super.initState();
    final s = widget.session.saved;
    if (s != null && s['g'] is List) {
      _g = [for (final v in s['g'] as List) (v as num).toInt()];
      _score = (s['score'] as num?)?.toInt() ?? 0;
    } else {
      _g = List.filled(16, 0);
      _spawn();
      _spawn();
    }
  }

  void _spawn() {
    final empty = [for (var i = 0; i < 16; i++) if (_g[i] == 0) i];
    if (empty.isEmpty) return;
    _g[empty[_rng.nextInt(empty.length)]] = _rng.nextDouble() < 0.9 ? 2 : 4;
  }

  List<int> _slide(List<int> line) {
    final vals = line.where((v) => v != 0).toList();
    final out = <int>[];
    for (var i = 0; i < vals.length; i++) {
      if (i + 1 < vals.length && vals[i] == vals[i + 1]) {
        out.add(vals[i] * 2);
        _score += vals[i] * 2;
        i++;
      } else {
        out.add(vals[i]);
      }
    }
    while (out.length < n) {
      out.add(0);
    }
    return out;
  }

  void _move(int dr, int dc) {
    final before = [..._g];
    for (var k = 0; k < n; k++) {
      final idx = [
        for (var j = 0; j < n; j++)
          dc != 0 ? k * n + (dc < 0 ? j : n - 1 - j) : (dr < 0 ? j : n - 1 - j) * n + k,
      ];
      final res = _slide([for (final i in idx) _g[i]]);
      for (var j = 0; j < n; j++) {
        _g[idx[j]] = res[j];
      }
    }
    if (List.generate(16, (i) => before[i] == _g[i]).every((x) => x)) return;
    setState(_spawn);
    widget.session.save({'g': _g, 'score': _score});
    final stuck = !_g.contains(0) && !List.generate(16, (i) => (i % n < n - 1 && _g[i] == _g[i + 1]) || (i + n < 16 && _g[i] == _g[i + n])).any((x) => x);
    if (stuck) widget.session.finish(GameOutcome(score: _score, summary: tr(context, 'Best tile ${_g.reduce(math.max)}', 'Mejor ficha ${_g.reduce(math.max)}')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Score: $_score', 'Puntos: $_score'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          MoveInput(
            onMove: _move,
            child: CellGrid(
              rows: n,
              cols: n,
              gap: 6,
              cell: (r, c) {
                final v = _g[r * n + c];
                final level = v == 0 ? 0.0 : (math.log(v) / math.ln2) / 11;
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: v == 0 ? scheme.surfaceContainerHighest : Color.lerp(scheme.primaryContainer, scheme.primary, level.clamp(0, 1)), borderRadius: BorderRadius.circular(10)),
                  child: v == 0 ? null : Text('$v', style: TextStyle(fontSize: v >= 1024 ? 18 : 24, fontWeight: FontWeight.w800, color: level > 0.45 ? scheme.onPrimary : scheme.onPrimaryContainer)),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ArrowPad(onMove: _move),
          GameActions(children: [PrismButton(label: tr(context, 'Finish here', 'Terminar aquí'), onPressed: () => widget.session.finish(GameOutcome(score: _score, summary: tr(context, 'Best tile ${_g.reduce(math.max)}', 'Mejor ficha ${_g.reduce(math.max)}'))))]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Light Switch Puzzle
// ---------------------------------------------------------------------------

class LightsGame extends StatefulWidget {
  const LightsGame({super.key, required this.session});
  final GameSession session;
  @override
  State<LightsGame> createState() => _LightsGameState();
}

class _LightsGameState extends State<LightsGame> {
  static const n = 5;
  late List<bool> _on;
  int _presses = 0;

  @override
  void initState() {
    super.initState();
    final rng = widget.session.rng(25);
    _on = List.filled(n * n, false);
    for (var k = 0; k < 8; k++) {
      _toggle(rng.nextInt(n * n), count: false);
    }
    if (!_on.contains(true)) _toggle(12, count: false);
  }

  void _toggle(int i, {bool count = true}) {
    final r = i ~/ n, c = i % n;
    for (final (dr, dc) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final rr = r + dr, cc = c + dc;
      if (rr >= 0 && rr < n && cc >= 0 && cc < n) _on[rr * n + cc] = !_on[rr * n + cc];
    }
    if (count) _presses++;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Tapping a light flips it and its neighbours. Turn them all off.', 'Tocar una luz la cambia a ella y a sus vecinas. Apágalas todas.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          CellGrid(
            rows: n,
            cols: n,
            gap: 6,
            cell: (r, c) {
              final i = r * n + c;
              return _box(
                context,
                radius: 12,
                color: _on[i] ? scheme.tertiary : scheme.surfaceContainerHighest,
                label: _on[i] ? 'On' : 'Off',
                onTap: () {
                  setState(() => _toggle(i));
                  if (!_on.contains(true)) widget.session.finish(GameOutcome(score: math.max(1, 40 - _presses), summary: tr(context, 'All off in $_presses taps', 'Todas apagadas en $_presses toques')));
                },
                child: Icon(_on[i] ? PhosphorIcons.lightbulb(PhosphorIconsStyle.fill) : PhosphorIcons.lightbulb(), color: _on[i] ? scheme.onTertiary : scheme.onSurfaceVariant),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Codebreaker
// ---------------------------------------------------------------------------

class CodebreakerGame extends StatefulWidget {
  const CodebreakerGame({super.key, required this.session});
  final GameSession session;
  @override
  State<CodebreakerGame> createState() => _CodebreakerGameState();
}

class _CodebreakerGameState extends State<CodebreakerGame> {
  late final List<int> _code = () {
    final rng = widget.session.rng(26);
    return List.generate(4, (_) => rng.nextInt(6) + 1);
  }();
  final List<List<int>> _guesses = [];
  List<int> _cur = [];

  (int, int) _fb(List<int> g) {
    var exact = 0;
    final a = <int, int>{}, b = <int, int>{};
    for (var i = 0; i < 4; i++) {
      if (g[i] == _code[i]) {
        exact++;
      } else {
        a[_code[i]] = (a[_code[i]] ?? 0) + 1;
        b[g[i]] = (b[g[i]] ?? 0) + 1;
      }
    }
    var near = 0;
    for (final e in b.entries) {
      near += math.min(e.value, a[e.key] ?? 0);
    }
    return (exact, near);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _guesses.isNotEmpty && (_fb(_guesses.last).$1 == 4 || _guesses.length >= 10);
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Find the 4-digit code (digits 1–6, repeats allowed). ● right digit, right place · ○ right digit, wrong place.', 'Encuentra el código de 4 cifras (1–6, se pueden repetir). ● cifra y lugar correctos · ○ cifra correcta, lugar no.'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          for (final g in _guesses)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(g.join('  '), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const SizedBox(width: 16),
                  Text('${'●' * _fb(g).$1}${'○' * _fb(g).$2}'.padRight(4, '·'), style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          if (!done) ...[
            const SizedBox(height: 8),
            Text(_cur.join('  ').padRight(7, '_'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (var d = 1; d <= 6; d++) SizedBox(width: 44, height: 44, child: _box(context, label: '$d', onTap: _cur.length < 4 ? () => setState(() => _cur.add(d)) : null, child: Text('$d', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
            ]),
            GameActions(children: [
              PrismButton(label: '⌫', onPressed: () => _cur.isEmpty ? null : setState(() => _cur.removeLast())),
              PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Try', 'Probar'), onPressed: () {
                if (_cur.length != 4) return;
                setState(() {
                  _guesses.add(_cur);
                  _cur = [];
                });
                final (exact, _) = _fb(_guesses.last);
                if (exact == 4 || _guesses.length >= 10) {
                  widget.session.finish(GameOutcome(score: exact == 4 ? 11 - _guesses.length : 0, max: 10, summary: exact == 4 ? tr(context, 'Cracked in ${_guesses.length}', 'Descifrado en ${_guesses.length}') : tr(context, 'The code was ${_code.join()}', 'El código era ${_code.join()}')));
                }
              }),
            ]),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pipe Connector
// ---------------------------------------------------------------------------

class PipeGame extends StatefulWidget {
  const PipeGame({super.key, required this.session});
  final GameSession session;
  @override
  State<PipeGame> createState() => _PipeGameState();
}

class _PipeGameState extends State<PipeGame> {
  static const n = 5;
  late List<Set<int>> _solved; // directions 0 up 1 right 2 down 3 left
  late List<int> _rot;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    final rng = widget.session.rng(27);
    _solved = List.generate(n * n, (_) => <int>{});
    final seen = {12};
    final frontier = <(int, int)>[];
    void addEdges(int c) {
      final r = c ~/ n, col = c % n;
      if (r > 0) frontier.add((c, 0));
      if (col < n - 1) frontier.add((c, 1));
      if (r < n - 1) frontier.add((c, 2));
      if (col > 0) frontier.add((c, 3));
    }

    addEdges(12);
    while (seen.length < n * n) {
      final (c, d) = frontier.removeAt(rng.nextInt(frontier.length));
      final nb = c + [-n, 1, n, -1][d];
      if (seen.contains(nb)) continue;
      _solved[c].add(d);
      _solved[nb].add((d + 2) % 4);
      seen.add(nb);
      addEdges(nb);
    }
    _rot = List.generate(n * n, (_) => rng.nextInt(4));
  }

  Set<int> _dirs(int i) => {for (final d in _solved[i]) (d + _rot[i]) % 4};

  Set<int> _connected() {
    final out = {12};
    final q = [12];
    while (q.isNotEmpty) {
      final c = q.removeLast();
      for (final d in _dirs(c)) {
        final r = c ~/ n, col = c % n;
        if ((d == 0 && r == 0) || (d == 2 && r == n - 1) || (d == 1 && col == n - 1) || (d == 3 && col == 0)) continue;
        final nb = c + [-n, 1, n, -1][d];
        if (_dirs(nb).contains((d + 2) % 4) && out.add(nb)) q.add(nb);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final con = _connected();
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Tap tiles to rotate them until every pipe connects to the centre.', 'Toca las piezas para girarlas hasta que todas las tuberías conecten con el centro.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          CellGrid(
            rows: n,
            cols: n,
            gap: 3,
            cell: (r, c) {
              final i = r * n + c;
              return _box(
                context,
                radius: 8,
                color: i == 12 ? scheme.tertiary.withValues(alpha: 0.3) : null,
                label: con.contains(i) ? 'Connected' : 'Not connected',
                onTap: () {
                  setState(() {
                    _rot[i] = (_rot[i] + 1) % 4;
                    _taps++;
                  });
                  if (_connected().length == n * n) widget.session.finish(GameOutcome(score: math.max(1, 60 - _taps ~/ 2), summary: tr(context, 'All connected in $_taps turns', 'Todo conectado en $_taps giros')));
                },
                child: CustomPaint(size: Size.infinite, painter: _PipePainter(_dirs(i), con.contains(i) ? scheme.primary : scheme.onSurfaceVariant)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PipePainter extends CustomPainter {
  _PipePainter(this.dirs, this.color);
  final Set<int> dirs;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.2
      ..strokeCap = StrokeCap.round;
    final c = Offset(s.width / 2, s.height / 2);
    for (final d in dirs) {
      final end = [Offset(c.dx, 0), Offset(s.width, c.dy), Offset(c.dx, s.height), Offset(0, c.dy)][d];
      canvas.drawLine(c, end, p);
    }
    canvas.drawCircle(c, s.width * 0.12, p);
  }

  @override
  bool shouldRepaint(_PipePainter o) => o.dirs != dirs || o.color != color;
}

// ---------------------------------------------------------------------------
// Tile Matching (triple match)
// ---------------------------------------------------------------------------

class TileMatchGame extends StatefulWidget {
  const TileMatchGame({super.key, required this.session});
  final GameSession session;
  @override
  State<TileMatchGame> createState() => _TileMatchGameState();
}

class _TileMatchGameState extends State<TileMatchGame> {
  static const symbols = ['🍓', '🌻', '🐚', '🍄', '⭐', '🫖', '🍋', '🪴'];
  late List<String?> _board;
  final List<String> _tray = [];
  int _cleared = 0;

  @override
  void initState() {
    super.initState();
    final rng = widget.session.rng(28);
    final picks = shuffled(symbols, rng).take(6).toList();
    _board = shuffled([for (final s in picks) ...List.filled(3, s), for (final s in picks.take(4)) ...List.filled(3, s)], rng);
  }

  void _tap(int i) {
    final s = _board[i];
    if (s == null || _tray.length >= 7) return;
    setState(() {
      _board[i] = null;
      _tray.add(s);
      _tray.sort();
      if (_tray.where((t) => t == s).length == 3) {
        _tray.removeWhere((t) => t == s);
        _cleared++;
      }
    });
    if (_board.every((b) => b == null) && _tray.isEmpty) {
      widget.session.finish(GameOutcome(score: _cleared, max: _cleared, summary: tr(context, 'Board cleared!', '¡Tablero despejado!')));
    } else if (_tray.length >= 7) {
      widget.session.finish(GameOutcome(score: _cleared, summary: tr(context, 'Tray full after $_cleared sets', 'Bandeja llena tras $_cleared tríos')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Tap tiles into the tray. Three alike disappear. Don\'t fill all 7 slots!', 'Toca fichas para llevarlas a la bandeja. Tres iguales desaparecen. ¡No llenes los 7 huecos!'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          CellGrid(rows: 5, cols: 6, gap: 4, cell: (r, c) {
            final i = r * 6 + c;
            final s = _board[i];
            return s == null ? const SizedBox.shrink() : _box(context, radius: 10, label: s, onTap: () => _tap(i), child: Text(s, style: const TextStyle(fontSize: 26)));
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [for (var k = 0; k < 7; k++) Expanded(child: Center(child: Text(k < _tray.length ? _tray[k] : '·', style: const TextStyle(fontSize: 24))))]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color Sequence (Simon) — also used for Color Memory
// ---------------------------------------------------------------------------

class ColorSequenceGame extends StatefulWidget {
  const ColorSequenceGame({super.key, required this.session, this.symbols = false});
  final GameSession session;

  /// Use symbols instead of colours (Sequence Recall).
  final bool symbols;
  @override
  State<ColorSequenceGame> createState() => _ColorSequenceGameState();
}

class _ColorSequenceGameState extends State<ColorSequenceGame> {
  late final math.Random _rng = widget.session.rng(29);
  final List<int> _seq = [];
  int _input = 0;
  int? _flash;
  bool _showing = false;
  static const _syms = ['🌙', '⭐', '🌸', '🍀', '🔥', '💧'];

  @override
  void initState() {
    super.initState();
    _seq.add(_rng.nextInt(4));
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play() async {
    setState(() => _showing = true);
    final reduce = MediaQuery.of(context).disableAnimations;
    for (final s in _seq) {
      await Future<void>.delayed(Duration(milliseconds: reduce ? 500 : 350));
      if (!mounted) return;
      setState(() => _flash = s);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _flash = null);
    }
    setState(() {
      _showing = false;
      _input = 0;
    });
  }

  void _tap(int k) {
    if (_showing) return;
    if (_seq[_input] != k) {
      widget.session.finish(GameOutcome(score: _seq.length - 1, summary: tr(context, 'Remembered ${_seq.length - 1} in a row', 'Recordaste ${_seq.length - 1} seguidos')));
      return;
    }
    _input++;
    if (_input == _seq.length) {
      _seq.add(_rng.nextInt(4));
      _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Column(
        children: [
          Text(_showing ? tr(context, 'Watch…', 'Observa…') : tr(context, 'Your turn — repeat the sequence (${_seq.length})', 'Tu turno: repite la secuencia (${_seq.length})'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          CellGrid(rows: 2, cols: 2, gap: 10, cell: (r, c) {
            final k = r * 2 + c;
            final (color, name, shape) = gameplayColors[k];
            final lit = _flash == k;
            return _box(
              context,
              radius: 18,
              selected: lit,
              color: widget.symbols ? (lit ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4) : null) : color.withValues(alpha: lit ? 1 : 0.35),
              label: widget.symbols ? _syms[k] : name,
              onTap: () => _tap(k),
              child: Text(widget.symbols ? _syms[k] : shape, style: TextStyle(fontSize: 34, color: widget.symbols ? null : Colors.white.withValues(alpha: lit ? 1 : 0.7))),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini Jigsaw (swap tiles of a generated picture)
// ---------------------------------------------------------------------------

class JigsawGame extends StatefulWidget {
  const JigsawGame({super.key, required this.session, this.size = 3});
  final GameSession session;
  final int size;
  @override
  State<JigsawGame> createState() => _JigsawGameState();
}

class _JigsawGameState extends State<JigsawGame> {
  late int n = widget.size;
  late List<int> _order;
  int? _pick;
  int _swaps = 0;
  late final String _scene;

  @override
  void initState() {
    super.initState();
    const scenes = ['🏡🌳☀️🌷🐈🌈🍄🐝🌼', '🌊⛵🐚🌞🐬🏝️🦀🌴⭐', '🌙✨🦉🌲🏕️🔥⭐🌌🦊', '🍰☕🍪🧁🍓🫖🍯🥐🍩', '🚀🪐🌍👩‍🚀🌟☄️🛸🌕🔭'];
    final rng = widget.session.rng(30);
    _scene = scenes[rng.nextInt(scenes.length)];
    _shuffle();
  }

  void _shuffle() {
    _order = shuffled(List.generate(n * n, (i) => i), widget.session.rng(31 + n));
    if (List.generate(n * n, (i) => _order[i] == i).every((x) => x)) _order = _order.reversed.toList();
    _swaps = 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emojis = _scene.characters.toList();
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Tap two pieces to swap them. Rebuild the picture!', 'Toca dos piezas para intercambiarlas. ¡Recompón la imagen!'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final side = box.maxWidth;
            final piece = side / n;
            Widget picture() => SizedBox(
              width: side,
              height: side,
              child: CustomPaint(
                painter: _ScenePainter(scheme),
                child: GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final e in emojis.take(9)) Center(child: Text(e, style: TextStyle(fontSize: side / 6)))],
                ),
              ),
            );
            return SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  for (var pos = 0; pos < n * n; pos++)
                    Positioned(
                      left: (pos % n) * piece,
                      top: (pos ~/ n) * piece,
                      width: piece,
                      height: piece,
                      child: GestureDetector(
                        onTap: () {
                          if (_pick == null) return setState(() => _pick = pos);
                          setState(() {
                            final t = _order[_pick!];
                            _order[_pick!] = _order[pos];
                            _order[pos] = t;
                            _pick = null;
                            _swaps++;
                          });
                          if (List.generate(n * n, (i) => _order[i] == i).every((x) => x)) {
                            widget.session.finish(GameOutcome(score: math.max(1, 30 - _swaps), summary: tr(context, 'Pieced together in $_swaps swaps', 'Recompuesta en $_swaps cambios')));
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: _pick == pos ? scheme.primary : scheme.surface, width: _pick == pos ? 3 : 1)),
                          child: ClipRect(
                            child: OverflowBox(
                              maxWidth: side,
                              maxHeight: side,
                              alignment: Alignment(n == 1 ? 0 : -1 + 2 * (_order[pos] % n) / (n - 1), n == 1 ? 0 : -1 + 2 * (_order[pos] ~/ n) / (n - 1)),
                              child: picture(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scheme);
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primaryContainer, scheme.tertiaryContainer, scheme.secondaryContainer]).createShader(rect));
    final p = Paint()..color = scheme.surface.withValues(alpha: 0.18);
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(Offset(s.width * (0.15 + 0.15 * i), s.height * (0.2 + 0.12 * (i % 3))), s.width * 0.08, p);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter o) => o.scheme != scheme;
}

// ---------------------------------------------------------------------------
// Spot the Difference
// ---------------------------------------------------------------------------

class SpotDifferenceGame extends StatefulWidget {
  const SpotDifferenceGame({super.key, required this.session});
  final GameSession session;
  @override
  State<SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

class _SpotDifferenceGameState extends State<SpotDifferenceGame> {
  static const pool = ['🌸', '🌼', '🍄', '🐞', '🦋', '🌿', '🍓', '🐝', '🌷', '🍀', '🐌', '🌻', '🍂', '🌱'];
  late final List<String> _left;
  late final List<String> _right;
  late final Set<int> _diff;
  final Set<int> _found = {};
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    final rng = widget.session.rng(32);
    _left = List.generate(30, (_) => pool[rng.nextInt(pool.length)]);
    _right = [..._left];
    _diff = {};
    while (_diff.length < 5) {
      _diff.add(rng.nextInt(30));
    }
    for (final i in _diff) {
      var s = _right[i];
      while (s == _left[i]) {
        s = pool[rng.nextInt(pool.length)];
      }
      _right[i] = s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget grid(List<String> items, bool tappable) => CellGrid(rows: 5, cols: 6, gap: 2, cell: (r, c) {
      final i = r * 6 + c;
      return GestureDetector(
        onTap: !tappable
            ? null
            : () {
                if (_diff.contains(i)) {
                  setState(() => _found.add(i));
                  if (_found.length == _diff.length) widget.session.finish(GameOutcome(score: math.max(1, 5 - _misses ~/ 2), max: 5, summary: tr(context, 'Found all 5 differences', 'Encontraste las 5 diferencias')));
                } else {
                  setState(() => _misses++);
                }
              },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _found.contains(i) ? scheme.primary.withValues(alpha: 0.25) : scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(6), border: _found.contains(i) ? Border.all(color: scheme.primary, width: 2) : null),
          child: Text(items[i], style: const TextStyle(fontSize: 20)),
        ),
      );
    });
    return GamePanel(
      child: Column(
        children: [
          Text(tr(context, 'Five things changed in the second garden. Tap them there.', 'Cinco cosas cambiaron en el segundo jardín. Tócalas ahí.'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          grid(_left, false),
          const SizedBox(height: 10),
          grid(_right, true),
          const SizedBox(height: 8),
          Text(tr(context, 'Found ${_found.length} / 5', 'Encontradas ${_found.length} / 5')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connect the Dots
// ---------------------------------------------------------------------------

/// Outlines as points in a 0–100 box.
const dotPictures = <String, List<(double, double)>>{
  'Star': [(50, 5), (61, 38), (95, 38), (67, 58), (78, 92), (50, 71), (22, 92), (33, 58), (5, 38), (39, 38), (50, 5)],
  'Heart': [(50, 90), (15, 55), (8, 32), (20, 15), (38, 14), (50, 28), (62, 14), (80, 15), (92, 32), (85, 55), (50, 90)],
  'House': [(20, 90), (20, 45), (50, 15), (80, 45), (80, 90), (58, 90), (58, 65), (42, 65), (42, 90), (20, 90)],
  'Fish': [(10, 50), (30, 30), (55, 25), (75, 40), (92, 25), (88, 50), (92, 75), (75, 60), (55, 75), (30, 70), (10, 50)],
  'Moon': [(60, 10), (35, 20), (22, 45), (28, 72), (52, 88), (78, 82), (58, 72), (46, 52), (48, 30), (60, 10)],
  'Diamond': [(50, 8), (88, 40), (50, 92), (12, 40), (50, 8)],
  'Bell': [(50, 10), (40, 18), (35, 40), (30, 65), (18, 78), (82, 78), (70, 65), (65, 40), (60, 18), (50, 10)],
};

class ConnectDotsGame extends StatefulWidget {
  const ConnectDotsGame({super.key, required this.session});
  final GameSession session;
  @override
  State<ConnectDotsGame> createState() => _ConnectDotsGameState();
}

class _ConnectDotsGameState extends State<ConnectDotsGame> {
  late final String _name = (dotPictures.keys.toList()..shuffle(widget.session.rng(33))).first;
  late final List<(double, double)> _pts = dotPictures[_name]!;
  int _next = 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _next >= _pts.length;
    return GamePanel(
      child: Column(
        children: [
          Text(done ? tr(context, 'It\'s a $_name!', '¡Es una figura: $_name!') : tr(context, 'Tap the dots in order, starting at 1.', 'Toca los puntos en orden, empezando por el 1.'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final s = box.maxWidth / 100;
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _LinesPainter([for (var i = 0; i < _next; i++) Offset(_pts[i].$1 * s, _pts[i].$2 * s)], scheme.primary, done))),
                  for (var i = 0; i < _pts.length - 1; i++)
                    Positioned(
                      left: _pts[i].$1 * s - 18,
                      top: _pts[i].$2 * s - 18,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () {
                          final target = _next % (_pts.length - 1);
                          if (i != target) return;
                          setState(() => _next++);
                          if (_next >= _pts.length) widget.session.finish(GameOutcome(score: 1, max: 1, summary: tr(context, 'Drew a $_name', 'Dibujaste: $_name')));
                        },
                        child: Center(
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: i < _next ? scheme.primary : scheme.surfaceContainerHighest, border: Border.all(color: scheme.outline)),
                            child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i < _next ? scheme.onPrimary : scheme.onSurface)),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.pts, this.color, this.fill);
  final List<Offset> pts;
  final Color color;
  final bool fill;
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    if (fill) canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_LinesPainter o) => true;
}

// ---------------------------------------------------------------------------
// Logic Grid (small deduction puzzles)
// ---------------------------------------------------------------------------

class LogicPuzzle {
  const LogicPuzzle(this.people, this.things, this.thingLabel, this.clues, this.answer);
  final List<String> people;
  final List<String> things;
  final String thingLabel;
  final List<String> clues;

  /// people[i] → things[answer[i]].
  final List<int> answer;
}

const logicPuzzles = <LogicPuzzle>[
  LogicPuzzle(['Ash', 'Bea', 'Cal'], ['tea', 'cocoa', 'juice'], 'drink', ['Bea doesn\'t like hot drinks.', 'Ash isn\'t drinking tea.'], [1, 2, 0]),
  LogicPuzzle(['Dee', 'Eli', 'Fin'], ['cat', 'dog', 'fish'], 'pet', ['Eli\'s pet barks.', 'Fin\'s pet doesn\'t have fur.'], [0, 1, 2]),
  LogicPuzzle(['Gus', 'Hal', 'Ivy'], ['red', 'blue', 'green'], 'scarf', ['Ivy\'s scarf is the colour of grass.', 'Gus doesn\'t wear red.'], [1, 0, 2]),
  LogicPuzzle(['Jo', 'Kai', 'Lux'], ['piano', 'drums', 'flute'], 'instrument', ['Kai plays with sticks.', 'Jo\'s instrument has no keys.'], [2, 1, 0]),
  LogicPuzzle(['Max', 'Nia', 'Oz', 'Pip'], ['Mon', 'Tue', 'Wed', 'Thu'], 'day off', ['Nia\'s day off is right after Max\'s.', 'Pip is off on Thursday.', 'Oz isn\'t off on Monday or Tuesday.'], [0, 1, 2, 3]),
  LogicPuzzle(['Quin', 'Rae', 'Sol', 'Tam'], ['rose', 'tulip', 'daisy', 'lily'], 'flower', ['Rae\'s flower has thorns.', 'Tam\'s flower is white and yellow and often picked for "loves me, loves me not".', 'Quin didn\'t pick the lily.'], [1, 0, 3, 2]),
];

class LogicGridGame extends StatefulWidget {
  const LogicGridGame({super.key, required this.session});
  final GameSession session;
  @override
  State<LogicGridGame> createState() => _LogicGridGameState();
}

class _LogicGridGameState extends State<LogicGridGame> {
  late final LogicPuzzle _p = logicPuzzles[widget.session.rng(34).nextInt(logicPuzzles.length)];
  late final List<int> _marks = List.filled(_p.people.length * _p.things.length, 0); // 0 ?, 1 ✓, 2 ✗
  String? _msg;
  int _checks = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = _p.people.length;
    return GamePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'Each person has a different ${_p.thingLabel}. Tap cells to mark ✓ or ✗.', 'Cada persona tiene un ${_p.thingLabel} distinto. Toca para marcar ✓ o ✗.'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final c in _p.clues) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $c')),
          const SizedBox(height: 10),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [const SizedBox(), for (final t in _p.things) Center(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)))]),
              for (var i = 0; i < n; i++)
                TableRow(children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text(_p.people[i], style: const TextStyle(fontWeight: FontWeight.w700))),
                  for (var j = 0; j < n; j++)
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: SizedBox(
                        height: 42,
                        child: _box(context, label: '${_p.people[i]} ${_p.things[j]}', onTap: () => setState(() => _marks[i * n + j] = (_marks[i * n + j] + 1) % 3), child: Text(['', '✓', '✗'][_marks[i * n + j]], style: TextStyle(fontSize: 20, color: _marks[i * n + j] == 1 ? scheme.primary : scheme.error))),
                      ),
                    ),
                ]),
            ],
          ),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, textAlign: TextAlign.center)),
          GameActions(children: [
            PrismButton(tone: PrismButtonTone.filled, label: tr(context, 'Check', 'Comprobar'), onPressed: () {
              _checks++;
              final ok = List.generate(n, (i) => _marks[i * n + _p.answer[i]] == 1 && List.generate(n, (j) => j == _p.answer[i] || _marks[i * n + j] != 1).every((x) => x)).every((x) => x);
              if (ok) {
                widget.session.finish(GameOutcome(score: math.max(1, 4 - _checks), max: 3, summary: tr(context, 'Solved!', '¡Resuelto!')));
              } else {
                setState(() => _msg = tr(context, 'Not quite — re-read the clues.', 'Todavía no: vuelve a leer las pistas.'));
              }
            }),
          ]),
        ],
      ),
    );
  }
}
