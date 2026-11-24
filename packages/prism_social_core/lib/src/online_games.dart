/// Online party games: pure, deterministic rules shared by the server (which
/// is the referee) and the app (which draws the board).
///
/// A room's state is plain JSON so it can travel over HTTP unchanged.
library;

class GameMoveError implements Exception {
  const GameMoveError(this.code);
  final String code;
  @override
  String toString() => 'GameMoveError($code)';
}

abstract class OnlineGame {
  const OnlineGame();
  String get id;
  String get name;
  String get emoji;
  String get blurb;
  int get minPlayers;
  int get maxPlayers;

  Map<String, Object?> initial(int players);

  /// Applies [move] by player [seat]; throws [GameMoveError] when illegal.
  Map<String, Object?> apply(
    Map<String, Object?> state,
    int seat,
    Object? move,
  );

  /// What [seat] is allowed to see (hides secret choices). Defaults to all.
  Map<String, Object?> viewFor(Map<String, Object?> state, int seat) => state;

  /// Seat whose turn it is, or null when everyone may move (or it's over).
  int? turn(Map<String, Object?> state) => state['turn'] as int?;

  bool finished(Map<String, Object?> state) => state['done'] == true;

  /// Winning seats (empty for a draw).
  List<int> winners(Map<String, Object?> state) => [
    for (final w in (state['winners'] as List? ?? const [])) (w as num).toInt(),
  ];
}

int _int(Object? v, String code) {
  if (v is num && v == v.toInt()) return v.toInt();
  if (v is String && int.tryParse(v) != null) return int.parse(v);
  throw GameMoveError(code);
}

void _mustBeTurn(Map<String, Object?> s, int seat) {
  if (s['done'] == true) throw const GameMoveError('game_over');
  if (s['turn'] != seat) throw const GameMoveError('not_your_turn');
}

class TicTacToe extends OnlineGame {
  const TicTacToe();
  @override
  String get id => 'tictactoe';
  @override
  String get name => 'Tic-tac-toe';
  @override
  String get emoji => '⭕';
  @override
  String get blurb => 'Three in a row wins.';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 2;

  static const lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  @override
  Map<String, Object?> initial(int players) => {
    'board': List<int>.filled(9, -1),
    'turn': 0,
    'done': false,
    'winners': <int>[],
  };

  @override
  Map<String, Object?> apply(Map<String, Object?> s, int seat, Object? move) {
    _mustBeTurn(s, seat);
    final i = _int(move, 'bad_cell');
    final board = [for (final c in s['board']! as List) (c as num).toInt()];
    if (i < 0 || i > 8 || board[i] != -1) throw const GameMoveError('bad_cell');
    board[i] = seat;
    final won = lines.any((l) => l.every((x) => board[x] == seat));
    final full = !board.contains(-1);
    return {
      'board': board,
      'turn': won || full ? null : 1 - seat,
      'done': won || full,
      'winners': won ? [seat] : <int>[],
      'last': i,
    };
  }
}

class ConnectFour extends OnlineGame {
  const ConnectFour();
  static const cols = 7, rows = 6;
  @override
  String get id => 'connect4';
  @override
  String get name => 'Four in a Row';
  @override
  String get emoji => '🔴';
  @override
  String get blurb => 'Drop discs; line up four.';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 2;

  @override
  Map<String, Object?> initial(int players) => {
    'board': List<int>.filled(cols * rows, -1),
    'turn': 0,
    'done': false,
    'winners': <int>[],
  };

  static bool fourFrom(List<int> b, int r, int c, int seat) {
    int count(int dr, int dc) {
      var n = 0, rr = r + dr, cc = c + dc;
      while (rr >= 0 &&
          rr < rows &&
          cc >= 0 &&
          cc < cols &&
          b[rr * cols + cc] == seat) {
        n++;
        rr += dr;
        cc += dc;
      }
      return n;
    }

    for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      if (1 + count(dr, dc) + count(-dr, -dc) >= 4) return true;
    }
    return false;
  }

  @override
  Map<String, Object?> apply(Map<String, Object?> s, int seat, Object? move) {
    _mustBeTurn(s, seat);
    final c = _int(move, 'bad_column');
    if (c < 0 || c >= cols) throw const GameMoveError('bad_column');
    final board = [for (final x in s['board']! as List) (x as num).toInt()];
    // Row 0 is the top; discs fall to the lowest empty row.
    var r = rows - 1;
    while (r >= 0 && board[r * cols + c] != -1) {
      r--;
    }
    if (r < 0) throw const GameMoveError('column_full');
    board[r * cols + c] = seat;
    final won = fourFrom(board, r, c, seat);
    final full = !board.contains(-1);
    return {
      'board': board,
      'turn': won || full ? null : 1 - seat,
      'done': won || full,
      'winners': won ? [seat] : <int>[],
      'last': r * cols + c,
    };
  }
}

/// Rock, paper, scissors: everyone picks in secret; first to 3 round wins.
class RockPaperScissors extends OnlineGame {
  const RockPaperScissors();
  static const choices = ['rock', 'paper', 'scissors'];
  static const target = 3;
  @override
  String get id => 'rps';
  @override
  String get name => 'Rock, Paper, Scissors';
  @override
  String get emoji => '✊';
  @override
  String get blurb => 'Secret picks — first to 3.';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 2;

  @override
  Map<String, Object?> initial(int players) => {
    'picks': [null, null],
    'score': [0, 0],
    'rounds': <Object?>[],
    'turn': null,
    'done': false,
    'winners': <int>[],
  };

  static int beats(String a, String b) => a == b
      ? 0
      : ((a == 'rock' && b == 'scissors') ||
                (a == 'paper' && b == 'rock') ||
                (a == 'scissors' && b == 'paper')
            ? 1
            : -1);

  @override
  Map<String, Object?> apply(Map<String, Object?> s, int seat, Object? move) {
    if (s['done'] == true) throw const GameMoveError('game_over');
    if (move is! String || !choices.contains(move))
      throw const GameMoveError('bad_choice');
    final picks = List<Object?>.from(s['picks']! as List);
    if (picks[seat] != null) throw const GameMoveError('already_picked');
    picks[seat] = move;
    final score = [for (final x in s['score']! as List) (x as num).toInt()];
    final rounds = List<Object?>.from(s['rounds']! as List);
    if (picks.every((p) => p != null)) {
      final r = beats(picks[0]! as String, picks[1]! as String);
      if (r == 1) score[0]++;
      if (r == -1) score[1]++;
      rounds.add({'picks': picks, 'winner': r == 0 ? null : (r == 1 ? 0 : 1)});
      final done = score.any((x) => x >= target);
      return {
        'picks': [null, null],
        'score': score,
        'rounds': rounds,
        'turn': null,
        'done': done,
        'winners': done ? [score[0] >= target ? 0 : 1] : <int>[],
      };
    }
    return {...s, 'picks': picks};
  }

  @override
  Map<String, Object?> viewFor(Map<String, Object?> s, int seat) {
    final picks = s['picks']! as List;
    return {
      ...s,
      'picks': [
        for (var i = 0; i < picks.length; i++)
          i == seat ? picks[i] : (picks[i] == null ? null : 'hidden'),
      ],
    };
  }
}

/// Word chain: each word starts with the last letter of the one before. No
/// repeats. Three strikes and you're out; last one standing wins.
class WordChain extends OnlineGame {
  const WordChain();
  @override
  String get id => 'wordchain';
  @override
  String get name => 'Word Chain';
  @override
  String get emoji => '🔤';
  @override
  String get blurb => 'Start with the last letter. No repeats.';
  @override
  int get minPlayers => 2;
  @override
  int get maxPlayers => 8;

  @override
  Map<String, Object?> initial(int players) => {
    'words': <Object?>[],
    'strikes': List<int>.filled(players, 0),
    'turn': 0,
    'done': false,
    'winners': <int>[],
  };

  static int? _next(List<int> strikes, int from) {
    for (var k = 1; k <= strikes.length; k++) {
      final i = (from + k) % strikes.length;
      if (strikes[i] < 3) return i;
    }
    return null;
  }

  @override
  Map<String, Object?> apply(Map<String, Object?> s, int seat, Object? move) {
    _mustBeTurn(s, seat);
    final strikes = [for (final x in s['strikes']! as List) (x as num).toInt()];
    final words = List<Object?>.from(s['words']! as List);
    final pass = move == null || (move is String && move.trim().isEmpty);
    final w = pass ? '' : '$move'.trim().toLowerCase();
    var ok = !pass && RegExp(r"^[a-záéíóúñü'-]{2,24}$").hasMatch(w);
    String? reason;
    if (pass) {
      reason = 'passed';
    } else if (!ok) {
      reason = 'not a word';
    } else if (words.any((x) => (x as Map)['word'] == w)) {
      ok = false;
      reason = 'already used';
    } else if (words.isNotEmpty) {
      final prev =
          ((words.lastWhere((x) => (x as Map)['ok'] == true, orElse: () => null)
                  as Map?)?['word']
              as String?);
      if (prev != null && prev.isNotEmpty && w[0] != prev[prev.length - 1]) {
        ok = false;
        reason = 'must start with “${prev[prev.length - 1]}”';
      }
    }
    if (!ok) strikes[seat]++;
    words.add({'seat': seat, 'word': w, 'ok': ok, 'reason': ?reason});
    final alive = [
      for (var i = 0; i < strikes.length; i++)
        if (strikes[i] < 3) i,
    ];
    final done = alive.length <= 1;
    return {
      'words': words.length > 200 ? words.sublist(words.length - 200) : words,
      'strikes': strikes,
      'turn': done ? null : _next(strikes, seat),
      'done': done,
      'winners': done ? alive : <int>[],
    };
  }
}

const onlineGames = <OnlineGame>[
  TicTacToe(),
  ConnectFour(),
  RockPaperScissors(),
  WordChain(),
];

OnlineGame? onlineGameById(String id) =>
    onlineGames.where((g) => g.id == id).firstOrNull;
