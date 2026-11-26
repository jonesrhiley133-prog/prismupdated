import 'dart:math' as math;

import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/cozy/data/cozy_data.dart';
import 'package:prism_plurality/features/cozy/views/collections_view.dart';
import 'package:prism_plurality/features/cozy/views/cozy_widgets.dart';
import 'package:prism_plurality/features/cozy/views/mailbox_view.dart';
import 'package:prism_plurality/features/games/content/prompt_bank.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _interviewQuestions = [
  'How would you introduce yourself to someone new?',
  'What do you enjoy doing most when you\'re around?',
  'What\'s something about you others might not know?',
  'What helps you feel safe?',
  'What\'s a small thing that makes your day better?',
  'If you had a theme song, what would it be?',
  'What\'s something you\'re proud of?',
  'What would your perfect day look like?',
  'What do you wish others in the system knew?',
  'What\'s a hobby you\'d like to try?',
];

const _writingPrompts = [
  'Write a letter to the system one year from now.',
  'Describe a cozy place that only exists in your imagination.',
  'Write a short poem about rain.',
  'Tell the story of a tiny adventure that happened today.',
  'Write about a door that leads somewhere unexpected.',
  'Describe your favourite season using all five senses.',
  'Write a thank-you note to something ordinary.',
  'Imagine the system as a house. Describe a room.',
];

const _diceTopics = [
  'food',
  'music',
  'childhood dreams',
  'animals',
  'travel',
  'books',
  'seasons',
  'hobbies',
  'films',
  'comfort',
  'the future',
  'nature',
];
const _diceAngles = [
  'your favourite thing about',
  'a funny story about',
  'something you\'d change about',
  'a memory of',
  'your hot take on',
  'what you\'d teach someone about',
];

/// One bonding activity and where it leads.
class _Activity {
  const _Activity(this.emoji, this.name, this.desc, this.go);
  final String emoji;
  final (String, String) name;
  final (String, String) desc;
  final void Function(BuildContext context, WidgetRef ref) go;
}

void _game(BuildContext c, String id) => c.go(AppRoutePaths.gamePlay(id));

final _activities = <_Activity>[
  _Activity(
    '🙋',
    ('Get to Know Me', 'Conóceme'),
    (
      'Answer questions about yourself and see who knows you.',
      'Responde sobre ti y mira quién te conoce.',
    ),
    (c, r) => _game(c, 'who_knows_me'),
  ),
  _Activity(
    '🎭',
    ('Two Truths and a Lie', 'Dos verdades y una mentira'),
    ('A classic guessing game.', 'Un clásico de adivinar.'),
    (c, r) => _game(c, 'two_truths'),
  ),
  _Activity(
    '⚖️',
    ('This or That', 'Esto o aquello'),
    ('Quick preference choices.', 'Elecciones rápidas.'),
    (c, r) => _game(c, 'this_or_that'),
  ),
  _Activity(
    '🤔',
    ('Would You Rather?', '¿Qué prefieres?'),
    ('Choose between two scenarios.', 'Elige entre dos opciones.'),
    (c, r) => _game(c, 'would_you_rather'),
  ),
  _Activity(
    '💫',
    ('Favourite Things Exchange', 'Intercambio de favoritos'),
    (
      'Swap favourite foods, places, smells…',
      'Compartid comidas, lugares, olores favoritos…',
    ),
    (c, r) => openCozyList(c, 'favorites'),
  ),
  _Activity(
    '💝',
    ('Compliment Exchange', 'Intercambio de cumplidos'),
    (
      'Drop compliments in the appreciation jar.',
      'Deja cumplidos en el tarro de aprecio.',
    ),
    (c, r) => openCozyList(c, 'appreciation'),
  ),
  _Activity(
    '💌',
    ('Appreciation Notes', 'Notas de aprecio'),
    (
      'Write a letter to someone you appreciate.',
      'Escribe una carta a alguien que aprecias.',
    ),
    (c, r) =>
        composeLetter(c, r, from: r.read(cozyMeProvider), subject: 'Thank you'),
  ),
  _Activity(
    '🪣',
    ('Shared Bucket List', 'Lista compartida de sueños'),
    ('Things to do together someday.', 'Cosas para hacer juntos algún día.'),
    (c, r) => openCozyList(c, 'bucket'),
  ),
  _Activity(
    '📸',
    ('Memory Sharing', 'Compartir recuerdos'),
    ('Add moments worth keeping.', 'Añade momentos que valga la pena guardar.'),
    (c, r) => openCozyList(c, 'memories'),
  ),
  _Activity(
    '🃏',
    ('Friendship Question Cards', 'Cartas de amistad'),
    (
      'Draw a question card and answer in the lounge.',
      'Saca una carta y responde en la sala.',
    ),
    (c, r) => _cards(c, r, '🃏', questionCards),
  ),
  _Activity(
    '🪞',
    ('Personality Comparisons', 'Comparar personalidades'),
    (
      'See where your preferences match.',
      'Mira dónde coinciden vuestras preferencias.',
    ),
    (c, r) => _game(c, 'this_or_that'),
  ),
  _Activity(
    '🧩',
    ('Common Interests Discovery', 'Descubrir intereses comunes'),
    (
      'Add interests — Prism finds the overlaps.',
      'Añade intereses: Prism encuentra coincidencias.',
    ),
    (c, r) => openCozyList(c, 'interests'),
  ),
  _Activity(
    '📜',
    ('Collaborative Storytelling', 'Historias en grupo'),
    (
      'Write a story one line at a time.',
      'Escribid una historia línea a línea.',
    ),
    (c, r) => _game(c, 'story_chain'),
  ),
  _Activity(
    '❓',
    ('Question of the Day', 'Pregunta del día'),
    (
      'Answer today\'s question in the Corner.',
      'Responde la pregunta de hoy en el Rincón.',
    ),
    (c, r) => c.go('${AppRoutePaths.cozy}?tab=corner'),
  ),
  _Activity(
    '🏅',
    ('Weekly Bonding Challenges', 'Retos semanales'),
    (
      'A gentle challenge for the week — optional, no streaks.',
      'Un reto suave para la semana: opcional, sin rachas.',
    ),
    (c, r) =>
        _cards(c, r, '🏅', kindnessChallenges, list: 'challenge', weekly: true),
  ),
  _Activity(
    '🎯',
    ('Shared Goal Setting', 'Metas compartidas'),
    ('Set goals to work on together.', 'Fijad metas para trabajar juntos.'),
    (c, r) => openCozyList(c, 'goals'),
  ),
  _Activity(
    '🎯',
    ('Friendship Bingo', 'Bingo de la amistad'),
    ('Complete friendly challenges over time.', 'Completa retos poco a poco.'),
    (c, r) => _game(c, 'friendship_bingo'),
  ),
  _Activity(
    '🎵',
    ('Favourite Song Exchange', 'Intercambio de canciones'),
    ('Share songs with each other.', 'Compartid canciones.'),
    (c, r) => openCozyList(c, 'music'),
  ),
  _Activity(
    '⭐',
    ('Guess My Favourite', 'Adivina mi favorito'),
    (
      'Predict each other\'s favourites.',
      'Predecid los favoritos de los demás.',
    ),
    (c, r) => _game(c, 'guess_favorite'),
  ),
  _Activity(
    '📀',
    ('Collaborative Playlists', 'Listas colaborativas'),
    ('Build a playlist together.', 'Haced una lista juntos.'),
    (c, r) => openCozyList(c, 'playlist'),
  ),
  _Activity(
    '🎙️',
    ('Alter Interviews', 'Entrevistas'),
    (
      'Interview questions — answers go to the lounge.',
      'Preguntas de entrevista: las respuestas van a la sala.',
    ),
    (c, r) => _cards(c, r, '🎙️', _interviewQuestions),
  ),
  _Activity(
    '🌈',
    ('Random Kindness Challenges', 'Retos de amabilidad'),
    ('A small act of kindness to try.', 'Un pequeño gesto amable para probar.'),
    (c, r) => _cards(c, r, '🌈', kindnessChallenges, list: 'challenge'),
  ),
  _Activity(
    '🎲',
    ('Conversation Dice', 'Dados de conversación'),
    (
      'Roll a topic and an angle, then talk.',
      'Tira un tema y un enfoque, y charlad.',
    ),
    (c, r) => _dice(c, r),
  ),
  _Activity(
    '✍️',
    ('Creative Writing Exchange', 'Intercambio de escritura'),
    (
      'A writing prompt to share with each other.',
      'Una idea de escritura para compartir.',
    ),
    (c, r) => _cards(c, r, '✍️', _writingPrompts),
  ),
  _Activity(
    '📓',
    ('Shared Journaling', 'Diario compartido'),
    (
      'Write a shared journal entry together.',
      'Escribid juntos una entrada de diario.',
    ),
    (c, r) async {
      final w = await composeSheet(
        c,
        r,
        title: tr(c, 'Shared journal entry', 'Entrada de diario compartida'),
      );
      if (w != null) {
        await r
            .read(trackerNotifierProvider.notifier)
            .create(
              kind: TrackerKind.journalEntry,
              title: '📓 Shared',
              body: w.text,
              memberId: w.author,
              occurredAt: DateTime.now(),
              tags: const ['cozy', 'shared'],
            );
        if (c.mounted)
          PrismToast.show(
            c,
            message: tr(c, 'Added to the Journal', 'Añadido al diario'),
          );
      }
    },
  ),
];

class TogetherView extends ConsumerStatefulWidget {
  const TogetherView({super.key});
  @override
  ConsumerState<TogetherView> createState() => _TogetherViewState();
}

class _TogetherViewState extends ConsumerState<TogetherView> {
  (String, String, int, bool)? _spin;
  bool _groupOnly = false;
  int _maxMinutes = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismSurface(
          tone: PrismSurfaceTone.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, '🎡 Activity roulette', '🎡 Ruleta de actividades'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrismChip(
                    label: tr(
                      context,
                      'Together-friendly',
                      'Para hacer juntos',
                    ),
                    selected: _groupOnly,
                    onTap: () => setState(() => _groupOnly = !_groupOnly),
                  ),
                  for (final m in const [5, 15, 60])
                    PrismChip(
                      label: m == 60
                          ? tr(context, 'Any length', 'Cualquier duración')
                          : '≤ $m min',
                      selected: _maxMinutes == m,
                      onTap: () => setState(() => _maxMinutes = m),
                    ),
                ],
              ),
              if (_spin != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${_spin!.$2}  ${_spin!.$1}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '~${_spin!.$3} min',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              PrismButton(
                tone: PrismButtonTone.filled,
                icon: PhosphorIcons.shuffle(),
                label: _spin == null
                    ? tr(context, 'Spin', 'Girar')
                    : tr(context, 'Spin again', 'Girar otra vez'),
                onPressed: () {
                  final pool = cozyActivities
                      .where(
                        (a) => (!_groupOnly || a.$4) && a.$3 <= _maxMinutes,
                      )
                      .toList();
                  if (pool.isNotEmpty)
                    setState(
                      () => _spin = pool[math.Random().nextInt(pool.length)],
                    );
                },
              ),
            ],
          ),
        ),
        PrismSectionHeader(
          title: tr(context, 'BONDING ACTIVITIES', 'ACTIVIDADES PARA CONECTAR'),
        ),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final a in _activities)
                PrismListRow(
                  leading: Text(a.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(cozyTr(context, a.name)),
                  subtitle: Text(cozyTr(context, a.desc)),
                  showChevron: true,
                  onTap: () => a.go(context, ref),
                ),
            ],
          ),
        ),
        PrismSectionHeader(
          title: tr(context, 'ELSEWHERE IN PRISM', 'EN OTRAS PARTES DE PRISM'),
        ),
        PrismSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              PrismListRow(
                leading: Icon(PhosphorIcons.chartBar()),
                title: Text(
                  tr(context, 'Start a system poll', 'Crear una encuesta'),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Uses Prism\'s Polls',
                    'Usa las encuestas de Prism',
                  ),
                ),
                showChevron: true,
                onTap: () => context.go(AppRoutePaths.polls),
              ),
              PrismListRow(
                leading: Icon(PhosphorIcons.images()),
                title: Text(
                  tr(context, 'Shared scrapbook', 'Álbum compartido'),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Make a page together',
                    'Haced una página juntos',
                  ),
                ),
                showChevron: true,
                onTap: () => context.go(AppRoutePaths.scrapbook),
              ),
              PrismListRow(
                leading: Icon(PhosphorIcons.gameController()),
                title: Text(
                  tr(
                    context,
                    'Plan a game night',
                    'Planear una noche de juegos',
                  ),
                ),
                showChevron: true,
                onTap: () => context.go('${AppRoutePaths.games}?tab=nights'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draws cards from [deck]; answers can go to the lounge, or the card can
/// be pinned to a collection.
Future<void> _cards(
  BuildContext context,
  WidgetRef ref,
  String emoji,
  List<String> deck, {
  String? list,
  bool weekly = false,
}) => PrismSheet.show<void>(
  context: context,
  title: emoji,
  builder: (_) => _CardDrawer(deck: deck, list: list, weekly: weekly),
);

class _CardDrawer extends ConsumerStatefulWidget {
  const _CardDrawer({required this.deck, this.list, this.weekly = false});
  final List<String> deck;
  final String? list;
  final bool weekly;
  @override
  ConsumerState<_CardDrawer> createState() => _CardDrawerState();
}

class _CardDrawerState extends ConsumerState<_CardDrawer> {
  late int _i = widget.weekly
      ? _weekIndex()
      : math.Random().nextInt(widget.deck.length);

  int _weekIndex() {
    final now = DateTime.now();
    final week = now.difference(DateTime(now.year)).inDays ~/ 7;
    return (now.year * 53 + week) % widget.deck.length;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.deck[_i];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.weekly)
            Text(
              tr(
                context,
                'This week\'s challenge (optional)',
                'Reto de esta semana (opcional)',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          PrismSurface(
            tone: PrismSurfaceTone.accent,
            child: Text(
              card,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                icon: PhosphorIcons.shuffle(),
                label: tr(context, 'Another', 'Otra'),
                onPressed: () => setState(
                  () => _i = math.Random().nextInt(widget.deck.length),
                ),
              ),
              PrismButton(
                icon: PhosphorIcons.chatCircleText(),
                label: tr(
                  context,
                  'Answer in the lounge',
                  'Responder en la sala',
                ),
                onPressed: () async {
                  final c = await composeSheet(
                    context,
                    ref,
                    title: tr(context, 'Answer', 'Responder'),
                    prompt: card,
                  );
                  if (c != null) {
                    await ref
                        .read(cozyActionsProvider)
                        .post(
                          body: c.text,
                          memberId: c.author,
                          starter: card,
                          mood: c.mood,
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
              ),
              if (widget.list != null)
                PrismButton(
                  icon: PhosphorIcons.pushPin(),
                  label: tr(context, 'Add to board', 'Añadir al tablón'),
                  onPressed: () async {
                    await ref
                        .read(cozyActionsProvider)
                        .addListItem(
                          widget.list!,
                          title: card,
                          memberId: ref.read(cozyMeProvider),
                        );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      PrismToast.show(
                        context,
                        message: tr(
                          context,
                          'Added to the challenge board',
                          'Añadido al tablón de retos',
                        ),
                      );
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

Future<void> _dice(BuildContext context, WidgetRef ref) {
  final rng = math.Random();
  final deck = [
    for (var i = 0; i < 30; i++)
      'Talk about ${_diceAngles[rng.nextInt(_diceAngles.length)]} ${_diceTopics[rng.nextInt(_diceTopics.length)]}.',
  ];
  return _cards(context, ref, '🎲', deck);
}
