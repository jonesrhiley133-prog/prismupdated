import 'dart:math' as math;

import 'package:prism_plurality/shared/ui_kit.dart';

/// Game categories, in hub order.
enum GameCategory {
  trivia('🧠', ('Trivia', 'Trivia')),
  word('🔤', ('Word Games', 'Juegos de palabras')),
  logic('🧩', ('Logic & Puzzles', 'Lógica y puzles')),
  cozy('🌿', ('Relaxing', 'Relajantes')),
  memory('🃏', ('Memory', 'Memoria')),
  social('🎉', ('Party & Social', 'Fiesta y social')),
  creative('🎨', ('Creative & Learning', 'Creativos y educativos'));

  const GameCategory(this.emoji, this.label);
  final String emoji;
  final (String, String) label;
}

/// How a game handles more than one alter.
enum PlayStyle {
  /// One alter plays; with several, each takes a turn on the same puzzle
  /// (pass & play) and results are compared.
  turns,

  /// Everyone plays inside the game together (prompts, stories, guessing).
  together,

  /// A shared creation that saves as it goes (canvases, projects).
  create,
}

/// What finishing a game produced.
class GameOutcome {
  const GameOutcome({
    this.score,
    this.max,
    this.summary = '',
    this.details = const {},
    this.memorable,
  });

  /// Null for activities without a score.
  final int? score;
  final int? max;
  final String summary;
  final Map<String, Object?> details;

  /// A line worth keeping (an answer, a story) for game-night recaps.
  final String? memorable;

  bool get scored => score != null;
}

/// Everything a game needs from the host.
class GameSession {
  GameSession({
    required this.def,
    required this.player,
    required this.players,
    required this.names,
    required this.seed,
    required this.save,
    required this.finish,
    this.saved,
    this.timer = false,
    this.custom,
  });

  final GameDef def;

  /// The alter whose turn it is (null: anyone / not chosen).
  final String? player;

  /// Everyone taking part.
  final List<String> players;
  final Map<String, String> names;

  /// Same seed → same puzzle (pass & play turns and challenges).
  final int seed;
  final Map<String, Object?>? saved;

  /// The player asked for a timer (only games that offer one use it).
  final bool timer;

  /// A custom game's content, when playing one.
  final Map<String, Object?>? custom;

  /// Autosave the game's state (debounced by the host).
  final void Function(Map<String, Object?> state) save;
  final void Function(GameOutcome outcome) finish;

  math.Random rng([int salt = 0]) => math.Random(seed * 31 + salt);

  String nameOf(String? id) => id == null ? '' : (names[id] ?? '');
}

typedef GameBuilder = Widget Function(GameSession session);

class GameDef {
  const GameDef({
    required this.id,
    required this.number,
    required this.category,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.howTo,
    required this.build,
    this.minutes = 5,
    this.minPlayers = 1,
    this.maxPlayers = 1,
    this.difficulty = 1,
    this.style = PlayStyle.turns,
    this.timerOption = false,
    this.seeded = true,
    this.saves = false,
    this.tags = const [],
  });

  final String id;
  final int number;
  final GameCategory category;
  final String emoji;
  final (String, String) name;
  final (String, String) desc;
  final (String, String) howTo;
  final GameBuilder build;
  final int minutes;
  final int minPlayers;
  final int maxPlayers;

  /// 1 easy, 2 medium, 3 hard.
  final int difficulty;
  final PlayStyle style;

  /// Offers an optional timer (never required).
  final bool timerOption;

  /// The same seed reproduces the game, so it can be challenged.
  final bool seeded;

  /// Keeps unfinished progress.
  final bool saves;

  /// Extra hub groupings: daily, quick, relaxing, party, educational,
  /// seasonal, collaborative.
  final List<String> tags;

  bool get multiplayer => maxPlayers > 1;
}

String trp(BuildContext c, (String, String) p) => tr(c, p.$1, p.$2);

String difficultyLabel(BuildContext c, int d) => switch (d) {
  1 => tr(c, 'Easy', 'Fácil'),
  2 => tr(c, 'Medium', 'Media'),
  _ => tr(c, 'Hard', 'Difícil'),
};

String playersLabel(BuildContext c, GameDef d) => d.maxPlayers <= 1
    ? tr(c, 'Solo', 'Individual')
    : d.minPlayers <= 1
    ? tr(c, '1–${d.maxPlayers} alters', '1–${d.maxPlayers} alters')
    : tr(
        c,
        '${d.minPlayers}–${d.maxPlayers} alters',
        '${d.minPlayers}–${d.maxPlayers} alters',
      );

/// Today's seed, the same for everyone (daily puzzles).
int dailySeed([DateTime? now]) {
  final d = now ?? DateTime.now();
  return d.year * 10000 + d.month * 100 + d.day;
}

/// A tidy panel used inside games.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      PrismSurface(padding: padding, child: child);
}

/// Big centred prompt text.
class GamePrompt extends StatelessWidget {
  const GamePrompt(this.text, {super.key, this.size = 20});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
  );
}

/// A tappable answer/option tile that follows the theme. [state]: null
/// neutral, true correct, false wrong. Shapes (✓ / ✗) back up colour.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.state,
    this.selected = false,
    this.leading,
  });
  final String label;
  final VoidCallback? onTap;
  final bool? state;
  final bool selected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = scheme.primary, bad = scheme.error;
    final border = state == true
        ? good
        : state == false
        ? bad
        : selected
        ? scheme.primary
        : scheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '$label${state == true
                ? ', correct'
                : state == false
                ? ', wrong'
                : ''}',
        child: Material(
          color: state == true
              ? good.withValues(alpha: 0.14)
              : state == false
              ? bad.withValues(alpha: 0.12)
              : selected
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: prismCorners(context, PrismTokens.radiusMedium),
            side: BorderSide(
              color: border,
              width: state == null && !selected ? 1 : 1.6,
            ),
          ),
          child: InkWell(
            borderRadius: prismCorners(context, PrismTokens.radiusMedium),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (state == true)
                    Icon(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: good,
                      size: 20,
                    ),
                  if (state == false)
                    Icon(
                      PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                      color: bad,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "3 / 10" progress line with a bar.
class GameProgress extends StatelessWidget {
  const GameProgress({
    super.key,
    required this.current,
    required this.total,
    this.trailing,
  });
  final int current;
  final int total;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            '$current / $total',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 6,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: prismCorners(context, 3),
              ),
              child: FractionallySizedBox(
                widthFactor: total == 0 ? 0 : (current / total).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: prismCorners(context, 3),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing!, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}

/// A countdown shown only when the player turned the timer on.
class GameTimer extends StatefulWidget {
  const GameTimer({
    super.key,
    required this.seconds,
    required this.onDone,
    this.running = true,
  });
  final int seconds;
  final VoidCallback onDone;
  final bool running;
  @override
  State<GameTimer> createState() => _GameTimerState();
}

class _GameTimerState extends State<GameTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.seconds),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    if (widget.running) _c.forward();
  }

  @override
  void didUpdateWidget(GameTimer old) {
    super.didUpdateWidget(old);
    if (widget.running && !_c.isAnimating && !_c.isCompleted) _c.forward();
    if (!widget.running) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final left = (widget.seconds * (1 - _c.value)).ceil();
        return Semantics(
          label: tr(context, '$left seconds left', 'Quedan $left segundos'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.timer(),
                size: 16,
                color: left <= 5
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${left}s',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: left <= 5 ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Primary action row at the bottom of a game.
class GameActions extends StatelessWidget {
  const GameActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: children,
    ),
  );
}

/// The theme-following colours for games that need several distinct
/// colours (colour matching keeps real colours; everything else adapts).
List<Color> gameColors(BuildContext context) {
  final s = Theme.of(context).colorScheme;
  return [
    s.primary,
    s.secondary,
    s.tertiary,
    s.error,
    Color.lerp(s.primary, s.tertiary, 0.5)!,
    Color.lerp(s.secondary, s.error, 0.5)!,
  ];
}

/// Fixed, colour-blind-friendly gameplay colours with names and shapes.
const gameplayColors = <(Color, String, String)>[
  (Color(0xFFE6550D), 'Orange', '●'),
  (Color(0xFF3182BD), 'Blue', '■'),
  (Color(0xFF31A354), 'Green', '▲'),
  (Color(0xFF756BB1), 'Purple', '◆'),
  (Color(0xFFFDD835), 'Yellow', '★'),
  (Color(0xFFE377C2), 'Pink', '✚'),
];

List<T> shuffled<T>(Iterable<T> list, math.Random rng) =>
    [...list]..shuffle(rng);
