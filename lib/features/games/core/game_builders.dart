/// Builds every game's widget. Loaded as a deferred library from the
/// catalog so game code and content banks load only when a game opens.
library;

import 'dart:math' as math;

import 'package:prism_plurality/features/games/content/prompt_bank.dart';
import 'package:prism_plurality/features/games/content/trivia_bank.dart';
import 'package:prism_plurality/features/games/content/word_bank.dart';
import 'package:prism_plurality/features/games/core/game_kit.dart';
import 'package:prism_plurality/features/games/engines/common_engines.dart';
import 'package:prism_plurality/features/games/engines/creative_engines.dart';
import 'package:prism_plurality/features/games/engines/grid_engines.dart';
import 'package:prism_plurality/features/games/engines/memory_engines.dart';
import 'package:prism_plurality/features/games/engines/quiz_engine.dart';
import 'package:prism_plurality/features/games/engines/social_engines.dart';
import 'package:prism_plurality/features/games/engines/word_engines.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _knowMeQuestions = [
  'What\'s my comfort food?',
  'Where would I go on a dream trip?',
  'What\'s my favourite season?',
  'What do I do to relax?',
  'What animal am I most like?',
  'What\'s a song I can\'t stop playing?',
  'What would my superpower be?',
  'Morning or night?',
  'What\'s my go-to drink?',
  'What hobby would I pick up with unlimited time?',
  'Which colour do I wear most?',
  'What scares me a little?',
  'What makes me laugh every time?',
  'What\'s my ideal rainy-day plan?',
  'Books, films or games?',
];

const _favoriteQuestions = [
  'Favourite colour?',
  'Favourite food?',
  'Favourite animal?',
  'Favourite season?',
  'Favourite film or show?',
  'Favourite song or band?',
  'Favourite smell?',
  'Favourite place?',
  'Favourite snack?',
  'Favourite holiday?',
  'Favourite word?',
  'Favourite time of day?',
  'Favourite drink?',
  'Favourite game?',
  'Favourite flower?',
];

const _poemStarts = [
  'The kettle sings a quiet tune…',
  'Under a sky of folded paper…',
  'We kept the lights on for each other…',
  'Rain on the window, soft as a secret…',
  'In the garden of many hands…',
  'The moon forgot its way home…',
];
const _associationStarts = ['Ocean', 'Blanket', 'Thunder', 'Garden', 'Lantern', 'Honey', 'Train', 'Winter', 'Library', 'Star'];
const _worldStarts = [
  'A world where it is always autumn',
  'An archipelago of floating islands',
  'A city built inside a giant tree',
  'A kingdom under a frozen sea',
  'A desert of glass and music',
  'A village on the back of a sleeping turtle',
];
const _worldSections = ['Name & feel', 'Places', 'Peoples & creatures', 'Customs', 'Magic or tech', 'Stories'];

SceneConfig _scene(String id) => switch (id) {
  'flower_arranging' => const SceneConfig(
    base: '🏺',
    backgrounds: [(Color(0xFFFFF4E6), Color(0xFFFFE0CC)), (Color(0xFFEFF7F1), Color(0xFFD6EFE0)), (Color(0xFFF3EEFF), Color(0xFFE2D8FF))],
    stickers: ['🌹', '🌷', '🌻', '🌼', '🌸', '💐', '🪻', '🌺', '🪷', '🌿', '🍃', '🌾', '🎀'],
  ),
  'tea_time' => const SceneConfig(
    backgrounds: [(Color(0xFFFFF8EE), Color(0xFFE9D8C4)), (Color(0xFFEAF4F4), Color(0xFFCCE3DE)), (Color(0xFFFDEFF4), Color(0xFFF7D6E0))],
    stickers: ['🫖', '☕', '🍵', '🧁', '🍰', '🍪', '🥐', '🍓', '🍋', '🍯', '🥄', '🌸', '🕯️', '🧈', '🥛'],
  ),
  'room_decorator' => const SceneConfig(
    backgrounds: [(Color(0xFFF6EFE7), Color(0xFFCDB49B)), (Color(0xFFE8EEF7), Color(0xFFB8C4D6)), (Color(0xFFEFE8F7), Color(0xFFC5B6D9))],
    stickers: ['🛋️', '🛏️', '🪑', '🪴', '🖼️', '🕯️', '📚', '🧸', '🪞', '🛁', '💡', '🪟', '🧺', '🎸', '🐈', '🧶', '📻', '🕰️'],
  ),
  'terrarium' => const SceneConfig(
    base: '🫙',
    backgrounds: [(Color(0xFFEFF7EE), Color(0xFFC9DFC4)), (Color(0xFFF2F0E6), Color(0xFFDCD3B8))],
    stickers: ['🌱', '🌿', '🍄', '🪨', '🌵', '🪴', '🐌', '🐞', '🦋', '🌸', '🍀', '🪵', '🐸', '✨'],
  ),
  'aquarium' => const SceneConfig(
    backgrounds: [(Color(0xFFBDE8F5), Color(0xFF3A86C8)), (Color(0xFFCFF3EE), Color(0xFF2A9D8F)), (Color(0xFF6C7FD8), Color(0xFF1B2A6B))],
    stickers: ['🐠', '🐟', '🐡', '🐙', '🦀', '🐚', '🪸', '🌿', '🪨', '🦑', '🐢', '🫧', '🐳', '🦐', '⭐'],
  ),
  'tiny_bakery' => const SceneConfig(
    backgrounds: [(Color(0xFFFFF1E6), Color(0xFFFAD2C2)), (Color(0xFFFFFBEA), Color(0xFFF5E6B8))],
    stickers: ['🎂', '🍰', '🧁', '🍩', '🍪', '🥧', '🍮', '🍓', '🍒', '🫐', '🍫', '🍬', '🌸', '🕯️', '✨', '🍋', '🥝'],
  ),
  'dream_landscape' => const SceneConfig(
    backgrounds: [(Color(0xFFFFD6A5), Color(0xFFB8E0D2)), (Color(0xFF20264A), Color(0xFF6D5BA8)), (Color(0xFFCDE7FF), Color(0xFFFFF5D6)), (Color(0xFFFFC8DD), Color(0xFFBDE0FE))],
    stickers: ['🏔️', '🌋', '🏝️', '🌳', '🌲', '🌴', '🏡', '🏰', '🌈', '☁️', '🌙', '⭐', '☀️', '🦋', '🐉', '🎈', '🌊', '🌸'],
  ),
  'flower_press' => const SceneConfig(
    backgrounds: [(Color(0xFFFBF7EF), Color(0xFFEDE3D1)), (Color(0xFFF5F0E8), Color(0xFFE4D9C8))],
    stickers: ['🌸', '🌼', '🌺', '🪻', '🌷', '🍀', '🍁', '🍂', '🌿', '🌾', '🪷', '🌹', '🍃'],
  ),
  _ => const SceneConfig(
    backgrounds: [(Color(0xFFDDEBFF), Color(0xFFF9F3E6)), (Color(0xFFFFE7D6), Color(0xFFFFF7EE)), (Color(0xFF1E2747), Color(0xFF52478A)), (Color(0xFFE6F4EA), Color(0xFFFFFFFF))],
    stickers: ['🏠', '🌳', '🌷', '🐈', '🐕', '🦊', '🐇', '☀️', '🌙', '⭐', '☁️', '🌈', '🎈', '🧺', '🚲', '⛺', '🔥', '🦋', '🍄', '🎪'],
  ),
};

/// The widget for game [id]. Custom games (with [GameSession.custom]) are
/// built from their template.
Widget buildGame(String id, GameSession s) {
  if (s.custom != null) return buildCustom(s);
  return switch (id) {
    // A — Trivia
    'trivia_general' => QuizGame(session: s, bank: triviaBanks['general']!),
    'trivia_geography' => QuizGame(session: s, bank: triviaBanks['geography']!),
    'trivia_history' => QuizGame(session: s, bank: triviaBanks['history']!),
    'trivia_science' => QuizGame(session: s, bank: triviaBanks['science']!),
    'trivia_animals' => QuizGame(session: s, bank: triviaBanks['animals']!),
    'trivia_music' => QuizGame(session: s, bank: triviaBanks['music']!),
    'trivia_movies' => QuizGame(session: s, bank: triviaBanks['movies']!),
    'trivia_literature' => QuizGame(session: s, bank: triviaBanks['literature']!),
    'trivia_space' => QuizGame(session: s, bank: triviaBanks['space']!),
    'trivia_food' => QuizGame(session: s, bank: triviaBanks['food']!),
    'trivia_mythology' => QuizGame(session: s, bank: triviaBanks['mythology']!),
    'trivia_technology' => QuizGame(session: s, bank: triviaBanks['technology']!),
    'trivia_art' => QuizGame(session: s, bank: triviaBanks['art']!),
    'trivia_sports' => QuizGame(session: s, bank: triviaBanks['sports']!),
    'trivia_language' => QuizGame(session: s, bank: triviaBanks['language']!),
    'trivia_nature' => QuizGame(session: s, bank: triviaBanks['nature']!),
    'true_false' => QuizGame(session: s, bank: trueFalse, count: 15, askDifficulty: false, seconds: 8),
    'guess_decade' => QuizGame(session: s, bank: decades, askDifficulty: false),
    'mystery_fact' => QuizGame(session: s, bank: mysteryFacts, askDifficulty: false),
    'trivia_marathon' => QuizGame(session: s, bank: allTrivia(), count: 20, marathon: true),
    // B — Words
    'word_scramble' => TypeWordGame(session: s, words: hintedWords, mode: TypeMode.scramble),
    'hangman' => HangmanGame(session: s, words: hintedWords),
    'word_search' => WordSearchGame(session: s, themes: searchThemes),
    'mini_crossword' => MiniCrosswordGame(session: s, clues: crosswordClues),
    'word_ladder' => WithDictionary(
      builder: (w) => WordLadderGame(session: s, ladders: ladders, words: w),
    ),
    'anagram' => WithDictionary(
      builder: (w) => AnagramGame(session: s, words: w),
    ),
    'missing_letters' => TypeWordGame(session: s, words: hintedWords, mode: TypeMode.missing),
    'word_association' => SharedTextGame(session: s, starters: _associationStarts, oneWord: true),
    'category_sprint' => CategoryGame(session: s, categories: categories, alphabet: false),
    'alphabet_challenge' => CategoryGame(session: s, categories: categories, alphabet: true),
    'synonym_match' => MatchPairsGame(session: s, pairs: synonyms),
    'antonym_match' => MatchPairsGame(session: s, pairs: antonyms),
    'definition_detective' => QuizGame(session: s, askDifficulty: false, bank: _fromPairs(definitions, (w, d) => d, (w, d) => w)),
    'rhyme_time' => QuizGame(
      session: s,
      askDifficulty: false,
      bank: [
        for (final (w, r, decoys) in rhymes) Q('Which word rhymes with "$w"?', [r, ...decoys]),
      ],
    ),
    'hidden_word' => HiddenWordGame(session: s, puzzles: hiddenWords),
    'five_letter' => WithDictionary(
      builder: (w) => FiveLetterGame(session: s, answers: fiveLetterAnswers, words: w),
    ),
    'sentence_builder' => OrderingGame(session: s, rounds: 5, prompt: 'Tap the words in order to build the sentence.', sets: [for (final x in sentences) ('', x.split(' '))]),
    'word_chain' => WithDictionary(
      builder: (w) => WordChainGame(session: s, words: w),
    ),
    'vocabulary_quest' => QuizGame(session: s, askDifficulty: false, bank: _fromPairs(vocabulary, (w, m) => 'What does "$w" mean?', (w, m) => m)),
    'finish_phrase' => QuizGame(
      session: s,
      askDifficulty: false,
      bank: [
        for (final (start, end, decoys) in phrases) Q('$start …', [end, ...decoys]),
      ],
    ),
    // C — Logic
    'sudoku' => SudokuGame(session: s),
    'mini_sudoku' => SudokuGame(session: s, size: 6),
    'nonograms' => NonogramGame(session: s),
    'sliding_puzzle' => SlidingPuzzleGame(session: s),
    'pattern_recognition' => GeneratedQuiz(session: s, make: _pattern),
    'sequence_solver' => GeneratedQuiz(session: s, make: _sequence),
    'logic_grid' => LogicGridGame(session: s),
    'mini_mazes' => MazeGame(session: s),
    'spot_difference' => SpotDifferenceGame(session: s),
    'odd_one_out' => GeneratedQuiz(session: s, make: _oddOneOut),
    'connect_dots' => ConnectDotsGame(session: s),
    'number_merge' => MergeGame(session: s),
    'tile_matching' => TileMatchGame(session: s),
    'pipe_connector' => PipeGame(session: s),
    'shape_sorting' => OrderingGame(session: s, rounds: 4, prompt: 'Order the shapes from fewest sides to most (a circle has none).', sets: _shapeSets(s)),
    'color_sequence' => ColorPatternGame(session: s),
    'balance_puzzle' => GeneratedQuiz(session: s, make: _balance),
    'mini_jigsaw' => JigsawGame(session: s),
    'codebreaker' => CodebreakerGame(session: s),
    'light_switch' => LightsGame(session: s),
    // D — Cozy
    'coloring_book' => ColoringGame(session: s),
    'sticker_scene' => StickerSceneGame(session: s, config: _scene('sticker_scene')),
    'zen_garden' => DrawGame(session: s, zen: true),
    'flower_arranging' || 'tea_time' || 'room_decorator' || 'terrarium' || 'aquarium' || 'tiny_bakery' || 'dream_landscape' || 'flower_press' => StickerSceneGame(session: s, config: _scene(id)),
    'cloud_watching' => CloudsGame(session: s),
    'star_connect' => StarConnectGame(session: s),
    'mandala' => DrawGame(session: s, symmetry: 8),
    'pixel_art' => PixelArtGame(session: s),
    'postcard' => PostcardGame(session: s),
    'mood_palette' => MoodPaletteGame(session: s),
    'outfit_creator' => OutfitGame(session: s),
    'friendship_bracelet' => BraceletGame(session: s),
    'origami' => OrderingGame(session: s, rounds: 2, prompt: 'Put the folding steps in order.', sets: [for (final e in origamiModels.entries) (e.key, e.value)]),
    // E — Memory
    'memory_match' => MemoryMatchGame(session: s),
    'sequence_recall' => ColorSequenceGame(session: s, symbols: true),
    'picture_recall' => RecallGame(session: s, kind: RecallKind.picture),
    'number_memory' => NumberMemoryGame(session: s),
    'color_memory' => ColorSequenceGame(session: s),
    'sound_match' => MemoryMatchGame(session: s, sounds: true),
    'object_detective' => RecallGame(session: s, kind: RecallKind.missing),
    'pattern_memory' => PatternMemoryGame(session: s),
    'quick_observation' => RecallGame(session: s, kind: RecallKind.observe),
    'shopping_list' => RecallGame(session: s, kind: RecallKind.shopping),
    // F — Social
    'would_you_rather' => PromptDeckGame(session: s, mode: DeckMode.choice, choices: wouldYouRather, choiceLabel: 'Would you rather…'),
    'never_have_i_ever' => PromptDeckGame(session: s, mode: DeckMode.haveNot, prompts: neverHaveIEver),
    'two_truths' => TwoTruthsGame(session: s),
    'guess_alter' => GuessAlterGame(session: s),
    'who_knows_me' => KnowMeGame(session: s, questions: _knowMeQuestions),
    'this_or_that' => PromptDeckGame(session: s, mode: DeckMode.choice, choices: thisOrThat, count: 15),
    'truth_or_dare' => PromptDeckGame(session: s, mode: DeckMode.truthDare, prompts: cozyTruths, dares: cozyDares),
    'guess_drawing' => GuessDrawingGame(session: s, prompts: drawingPrompts),
    'story_chain' => SharedTextGame(session: s, starters: storyStarts, hideEarlier: true),
    'emoji_charades' => QuizGame(
      session: s,
      askDifficulty: false,
      promptSize: 34,
      bank: [
        for (final (e, a, decoys) in emojiCharades) Q(e, [a, ...decoys]),
      ],
    ),
    'collab_poetry' => SharedTextGame(session: s, starters: _poemStarts, hint: 'Add a line to the poem'),
    'guess_favorite' => KnowMeGame(session: s, questions: _favoriteQuestions),
    'friendship_bingo' => BingoGame(session: s, squares: friendshipBingo),
    'conversation_roulette' => PromptDeckGame(session: s, mode: DeckMode.prompt, prompts: conversationStarters, writeAnswers: true),
    'mystery_personality' => QuizGame(
      session: s,
      askDifficulty: false,
      bank: [
        for (final (clues, a, decoys) in mysteryPersonalities) Q(clues.join(' · '), [a, ...decoys]),
      ],
    ),
    // G — Creative & learning
    'build_story' => GeneratorGame(
      session: s,
      title: 'Your story seed',
      parts: const {'Who': storyCharacters, 'Where': storyPlaces, 'Twist': storyTwists},
      compose: (p) => 'Once upon a time, ${p['Who']} lived in ${p['Where']}… ${p['Twist']}.',
      notesHint: 'Write your story here',
    ),
    'character_creator' => GeneratorGame(session: s, title: 'A new character', parts: characterParts, notesHint: 'Name, backstory, quirks…'),
    'comic_maker' => ComicGame(session: s),
    'drawing_prompt_jar' => PromptJarGame(session: s, prompts: drawingPrompts, emoji: '🫙'),
    'poetry_generator' => PoetryGame(session: s, words: poetryWords),
    'name_instrument' => QuizGame(
      session: s,
      askDifficulty: false,
      bank: [
        for (final (clue, a, decoys) in instruments) Q(clue, [a, ...decoys]),
      ],
    ),
    'rhythm_repeat' => RhythmGame(session: s),
    'music_notes' => MatchPairsGame(session: s, pairs: musicNotes, perRound: 4, rounds: 2, leftLabel: 'Symbol', rightLabel: 'Meaning'),
    'math_sprint' => GeneratedQuiz(session: s, make: _math, seconds: 15),
    'spelling' => QuizGame(session: s, bank: spelling, askDifficulty: false),
    'language_match' => LanguageMatch(session: s),
    'map_explorer' => MapExplorerGame(session: s, places: mapPlaces),
    'timeline_sort' => OrderingGame(
      session: s,
      rounds: 3,
      prompt: 'Oldest at the top, newest at the bottom.',
      sets: [
        for (final e in timelines.entries) (e.key, [for (final x in e.value) x.$1]),
      ],
      reveal: _yearOf,
    ),
    'invent_creature' => GeneratorGame(session: s, title: 'A brand-new creature', parts: creatureParts, notesHint: 'Name it, describe its habitat and habits…'),
    'worldbuilder' => SharedTextGame(session: s, starters: _worldStarts, sections: _worldSections),
    _ => Center(child: Text('Unknown game: $id')),
  };
}

String _yearOf(String event) {
  for (final list in timelines.values) {
    for (final (e, y) in list) {
      if (e == event) return y < 0 ? '${-y} BCE' : '$y';
    }
  }
  return '';
}

/// Questions from pairs: the prompt and the answer come from each pair; the
/// other three options are answers from other pairs.
List<Q> _fromPairs(List<(String, String)> pairs, String Function(String, String) prompt, String Function(String, String) answer) {
  final answers = [for (final (a, b) in pairs) answer(a, b)];
  return [
    for (var i = 0; i < pairs.length; i++)
      Q(prompt(pairs[i].$1, pairs[i].$2), [
        answers[i],
        ...[for (var k = 1; k <= 3; k++) answers[(i + k * 3) % answers.length]].where((x) => x != answers[i]).toSet().take(3),
      ]),
  ];
}

List<(String, List<String>)> _shapeSets(GameSession s) {
  final rng = s.rng(90);
  return [
    for (var i = 0; i < 6; i++)
      () {
        final pick = shuffled(shapesBySides, rng).take(5).toList()..sort((a, b) => a.$2.compareTo(b.$2));
        return ('', [for (final x in pick) x.$1]);
      }(),
  ];
}

Q _math(math.Random r, int d) {
  switch (d) {
    case 1:
      final a = r.nextInt(15) + 1, b = r.nextInt(15) + 1;
      return r.nextBool() ? Q('$a + $b = ?', numberOptions(a + b, r), '', 1) : Q('${a + b} − $b = ?', numberOptions(a, r), '', 1);
    case 2:
      final a = r.nextInt(11) + 2, b = r.nextInt(11) + 2;
      return r.nextBool() ? Q('$a × $b = ?', numberOptions(a * b, r, spread: 8), '', 2) : Q('${a * b} ÷ $b = ?', numberOptions(a, r), '', 2);
    default:
      final a = r.nextInt(9) + 2, b = r.nextInt(9) + 2, c = r.nextInt(20) + 1;
      return Q('$a × $b + $c = ?', numberOptions(a * b + c, r, spread: 9), 'Multiply first, then add.', 3);
  }
}

Q _sequence(math.Random r, int d) {
  if (d == 1) {
    final start = r.nextInt(10) + 1, step = r.nextInt(5) + 2;
    final seq = [for (var i = 0; i < 5; i++) start + step * i];
    return Q('${seq.take(4).join(', ')}, ?', numberOptions(seq[4], r), 'Add $step each time.', 1);
  }
  if (d == 2) {
    final start = r.nextInt(4) + 1, k = r.nextInt(2) + 2;
    final seq = [for (var i = 0; i < 5; i++) start * math.pow(k, i).toInt()];
    return Q('${seq.take(4).join(', ')}, ?', numberOptions(seq[4], r, spread: seq[4] ~/ 4 + 2), 'Multiply by $k each time.', 2);
  }
  switch (r.nextInt(3)) {
    case 0:
      final a = r.nextInt(5) + 1, b = r.nextInt(5) + 1;
      final seq = [a, b];
      while (seq.length < 6) {
        seq.add(seq[seq.length - 1] + seq[seq.length - 2]);
      }
      return Q('${seq.take(5).join(', ')}, ?', numberOptions(seq[5], r), 'Each number is the sum of the two before it.', 3);
    case 1:
      final off = r.nextInt(4);
      final seq = [for (var i = 1; i <= 5; i++) (i + off) * (i + off)];
      return Q('${seq.take(4).join(', ')}, ?', numberOptions(seq[4], r, spread: 6), 'Square numbers.', 3);
    default:
      final start = r.nextInt(10) + 2;
      final seq = [start];
      for (var i = 1; i < 5; i++) {
        seq.add(seq.last + i * 2);
      }
      return Q('${seq.take(4).join(', ')}, ?', numberOptions(seq[4], r), 'The gap grows by 2 each time.', 3);
  }
}

Q _pattern(math.Random r, int d) {
  const pool = ['🔴', '🔵', '🟢', '🟡', '🟣', '⭐', '🌙', '🔺', '⬛', '💧'];
  final syms = shuffled(pool, r).take(4).toList();
  final shapes = switch (d) {
    1 => [
      [0, 1],
      [0, 0, 1],
    ][r.nextInt(2)],
    2 => [
      [0, 1, 2],
      [0, 0, 1, 1],
      [0, 1, 1],
    ][r.nextInt(3)],
    _ => [
      [0, 1, 2, 1],
      [0, 1, 2, 3],
      [0, 0, 1, 2],
      [0, 1, 0, 2],
    ][r.nextInt(4)],
  };
  final seq = [for (var i = 0; i < shapes.length * 2 + 1; i++) syms[shapes[i % shapes.length]]];
  final answer = seq.removeLast();
  return Q('${seq.join(' ')}  ?', [answer, ...syms.where((x) => x != answer).take(3)], 'The pattern repeats every ${shapes.length}.', d);
}

Q _oddOneOut(math.Random r, int d) {
  final keys = shuffled(categories.keys, r);
  final main = categories[keys[0]]!, other = categories[keys[1]]!;
  final three = shuffled(main, r).take(3).toList();
  final odd = other[r.nextInt(other.length)];
  return Q('Which one doesn\'t belong?  ${shuffled([...three, odd], r).join(' · ')}', [odd, ...three], 'The others are all ${keys[0].toLowerCase()}.', d);
}

Q _balance(math.Random r, int d) {
  const items = ['🍎', '🍌', '🍇', '🧁', '🧸', '🪨'];
  final pick = shuffled(items, r);
  final a = r.nextInt(5) + 1 + d, b = r.nextInt(5) + 1;
  if (d == 1) {
    return Q('${pick[0]} + ${pick[0]} = ${a * 2}\n${pick[0]} = ?', numberOptions(a, r), 'Half of ${a * 2} is $a.', 1);
  }
  if (d == 2) {
    return Q('${pick[0]} + ${pick[0]} = ${a * 2}\n${pick[0]} + ${pick[1]} = ${a + b}\n${pick[1]} = ?', numberOptions(b, r), '${pick[0]} is $a, so ${pick[1]} is ${a + b} − $a = $b.', 2);
  }
  final c = r.nextInt(4) + 1;
  return Q(
    '${pick[0]} + ${pick[0]} + ${pick[0]} = ${a * 3}\n${pick[0]} + ${pick[1]} = ${a + b}\n${pick[1]} + ${pick[2]} = ${b + c}\n${pick[2]} = ?',
    numberOptions(c, r),
    '${pick[0]}=$a, ${pick[1]}=$b, ${pick[2]}=$c.',
    3,
  );
}

/// Language Match: choose a language, then match words.
class LanguageMatch extends StatefulWidget {
  const LanguageMatch({super.key, required this.session});
  final GameSession session;
  @override
  State<LanguageMatch> createState() => _LanguageMatchState();
}

class _LanguageMatchState extends State<LanguageMatch> {
  String? _lang;
  @override
  Widget build(BuildContext context) {
    if (_lang == null) {
      return GamePanel(
        child: Column(
          children: [
            GamePrompt(tr(context, 'Pick a language', 'Elige un idioma')),
            const SizedBox(height: 10),
            for (final l in languagePairs.keys) OptionTile(label: l, onTap: () => setState(() => _lang = l)),
          ],
        ),
      );
    }
    return MatchPairsGame(session: widget.session, pairs: languagePairs[_lang]!, leftLabel: _lang, rightLabel: 'English');
  }
}

/// Color Sequence (logic): copy the target pattern by tapping cells to cycle
/// colours. Bigger each round.
class ColorPatternGame extends StatefulWidget {
  const ColorPatternGame({super.key, required this.session});
  final GameSession session;
  @override
  State<ColorPatternGame> createState() => _ColorPatternGameState();
}

class _ColorPatternGameState extends State<ColorPatternGame> {
  late final math.Random _rng = widget.session.rng(91);
  int _round = 0;
  late List<int> _target, _mine;
  int _moves = 0;

  int get _n => 3 + (_round ~/ 2);
  int get _colors => math.min(4, 2 + _round);

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    _target = [for (var i = 0; i < _n * _n; i++) _rng.nextInt(_colors)];
    _mine = List.filled(_n * _n, 0);
  }

  Widget _grid(List<int> v, {ValueChanged<int>? onTap}) => AspectRatio(
    aspectRatio: 1,
    child: GridView.count(
      crossAxisCount: _n,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < v.length; i++)
          Semantics(
            button: onTap != null,
            label: gameplayColors[v[i]].$2,
            child: GestureDetector(
              onTap: onTap == null ? null : () => onTap(i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: gameplayColors[v[i]].$1, borderRadius: prismCorners(context, 6)),
                child: Text(gameplayColors[v[i]].$3, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final done = List.generate(_target.length, (i) => _target[i] == _mine[i]).every((x) => x);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _round + 1, total: 5, trailing: tr(context, '$_moves taps', '$_moves toques')),
        GamePanel(
          child: Column(
            children: [
              Text(
                tr(context, 'Copy the pattern on the left. Tap a cell to change its colour.', 'Copia el patrón de la izquierda. Toca una casilla para cambiar su color.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _grid(_target)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _grid(
                      _mine,
                      onTap: done
                          ? null
                          : (i) => setState(() {
                              _mine[i] = (_mine[i] + 1) % _colors;
                              _moves++;
                            }),
                    ),
                  ),
                ],
              ),
              if (done)
                GameActions(
                  children: [
                    Text(tr(context, '✓ Matched!', '✓ ¡Igual!'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    PrismButton(
                      tone: PrismButtonTone.filled,
                      label: _round + 1 >= 5 ? tr(context, 'Finish', 'Terminar') : tr(context, 'Next pattern', 'Siguiente patrón'),
                      onPressed: () {
                        if (_round + 1 >= 5) {
                          widget.session.finish(GameOutcome(score: 5, max: 5, summary: tr(context, '5 patterns in $_moves taps', '5 patrones en $_moves toques')));
                        } else {
                          setState(() {
                            _round++;
                            _deal();
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
// Custom games
// ---------------------------------------------------------------------------

/// Custom content format (stored on games.custom records):
///   type: trivia | friendship | choice | wordsearch | crossword | bingo |
///         memory | deck | flashcards | personality
Widget buildCustom(GameSession s) {
  final c = s.custom!;
  List<String> strings(String k) => [for (final v in (c[k] as List?) ?? const []) '$v'.trim()].where((x) => x.isNotEmpty).toList();
  List<(String, String)> pairs(String k) => [
    for (final v in (c[k] as List?) ?? const [])
      if (v is Map && '${v['a'] ?? ''}'.trim().isNotEmpty && '${v['b'] ?? ''}'.trim().isNotEmpty) ('${v['a']}'.trim(), '${v['b']}'.trim()),
  ];
  switch (c['type']) {
    case 'trivia':
    case 'friendship':
      final qs = [
        for (final v in (c['questions'] as List?) ?? const [])
          if (v is Map && (v['options'] as List?) != null && (v['options'] as List).length >= 2) Q('${v['q']}', [for (final o in v['options'] as List) '$o'], '${v['explain'] ?? ''}'),
      ];
      if (qs.isEmpty) return const _EmptyCustom();
      return QuizGame(session: s, bank: qs, count: qs.length, askDifficulty: false);
    case 'choice':
      final p = pairs('pairs');
      if (p.isEmpty) return const _EmptyCustom();
      return PromptDeckGame(session: s, mode: DeckMode.choice, choices: p, count: p.length);
    case 'wordsearch':
      final w = strings('words').map((x) => x.toUpperCase().replaceAll(RegExp('[^A-Z]'), '')).where((x) => x.length >= 3 && x.length <= 10).toList();
      if (w.length < 3) return const _EmptyCustom();
      return WordSearchGame(session: s, themes: {'${c['title'] ?? 'Custom'}': w});
    case 'crossword':
      final p = pairs('clues');
      if (p.length < 2) return const _EmptyCustom();
      return MiniCrosswordGame(session: s, clues: {for (final (a, b) in p) a.toUpperCase().replaceAll(RegExp('[^A-Z]'), ''): b});
    case 'bingo':
      final sq = strings('squares');
      if (sq.isEmpty) return const _EmptyCustom();
      return BingoGame(session: s, squares: [for (var i = 0; sq.length + i < 25; i++) sq[i % sq.length], ...sq]);
    case 'memory':
      final p = pairs('pairs');
      if (p.length < 2) return const _EmptyCustom();
      return MemoryMatchGame(session: s, pairs: p);
    case 'deck':
      final pr = strings('prompts');
      if (pr.isEmpty) return const _EmptyCustom();
      return PromptDeckGame(session: s, mode: DeckMode.prompt, prompts: pr, writeAnswers: true, count: pr.length);
    case 'flashcards':
      final p = pairs('pairs');
      if (p.length < 2) return const _EmptyCustom();
      return MatchPairsGame(session: s, pairs: p, rounds: (p.length / 5).ceil());
    case 'personality':
      return PersonalityQuizGame(session: s);
  }
  return const _EmptyCustom();
}

class _EmptyCustom extends StatelessWidget {
  const _EmptyCustom();
  @override
  Widget build(BuildContext context) => GamePanel(
    child: Text(
      tr(context, 'This custom game needs a bit more content. Edit it in Create to add more.', 'Este juego personalizado necesita más contenido. Edítalo en Crear.'),
      textAlign: TextAlign.center,
    ),
  );
}

/// "Which … are you?" — each option points to a result; the most-picked
/// result wins.
class PersonalityQuizGame extends StatefulWidget {
  const PersonalityQuizGame({super.key, required this.session});
  final GameSession session;
  @override
  State<PersonalityQuizGame> createState() => _PersonalityQuizGameState();
}

class _PersonalityQuizGameState extends State<PersonalityQuizGame> {
  late final List<String> _results = [for (final v in (widget.session.custom?['results'] as List?) ?? const []) '$v'];
  late final List<(String, List<(String, int)>)> _qs = [
    for (final v in (widget.session.custom?['questions'] as List?) ?? const [])
      if (v is Map)
        (
          '${v['q']}',
          [
            for (final o in (v['options'] as List?) ?? const [])
              if (o is Map) ('${o['t']}', (o['r'] as num?)?.toInt() ?? 0),
          ],
        ),
  ];
  int _i = 0;
  final Map<int, int> _tally = {};

  @override
  Widget build(BuildContext context) {
    if (_qs.isEmpty || _results.isEmpty) return const _EmptyCustom();
    final (q, opts) = _qs[_i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameProgress(current: _i + 1, total: _qs.length),
        GamePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GamePrompt(q),
              const SizedBox(height: 10),
              for (final (t, r) in opts)
                OptionTile(
                  label: t,
                  onTap: () {
                    _tally[r] = (_tally[r] ?? 0) + 1;
                    if (_i + 1 >= _qs.length) {
                      final best = _tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
                      widget.session.finish(GameOutcome(summary: _results[best.clamp(0, _results.length - 1)], memorable: _results[best.clamp(0, _results.length - 1)]));
                    } else {
                      setState(() => _i++);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
