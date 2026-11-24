import 'package:prism_social_core/prism_social_core.dart';
import 'package:test/test.dart';

void main() {
  test('tic-tac-toe: turns, illegal moves, win', () {
    const g = TicTacToe();
    var s = g.initial(2);
    s = g.apply(s, 0, 0);
    expect(() => g.apply(s, 0, 1), throwsA(isA<GameMoveError>()));
    expect(() => g.apply(s, 1, 0), throwsA(isA<GameMoveError>()));
    s = g.apply(s, 1, 3);
    s = g.apply(s, 0, 1);
    s = g.apply(s, 1, 4);
    s = g.apply(s, 0, 2);
    expect(g.finished(s), isTrue);
    expect(g.winners(s), [0]);
  });

  test('four in a row: gravity and diagonal win', () {
    const g = ConnectFour();
    var s = g.initial(2);
    for (final (seat, c) in [(0, 0), (1, 1), (0, 1), (1, 2), (0, 2), (1, 3), (0, 2), (1, 3), (0, 3), (1, 6), (0, 3)]) {
      s = g.apply(s, seat, c);
    }
    expect(g.winners(s), [0]);
  });

  test('rock paper scissors hides the other pick until both chose', () {
    const g = RockPaperScissors();
    var s = g.initial(2);
    s = g.apply(s, 0, 'rock');
    expect(g.viewFor(s, 1)['picks'], ['hidden', null]);
    expect(() => g.apply(s, 0, 'paper'), throwsA(isA<GameMoveError>()));
    s = g.apply(s, 1, 'scissors');
    expect(s['score'], [1, 0]);
    for (var i = 0; i < 2; i++) {
      s = g.apply(g.apply(s, 0, 'paper'), 1, 'rock');
    }
    expect(g.winners(s), [0]);
  });

  test('word chain: letters, repeats, strikes', () {
    const g = WordChain();
    var s = g.initial(3);
    s = g.apply(s, 0, 'apple');
    s = g.apply(s, 1, 'egg');
    s = g.apply(s, 2, 'apple'); // repeat → strike
    expect((s['strikes']! as List)[2], 1);
    s = g.apply(s, 0, 'goat');
    s = g.apply(s, 1, 'banana'); // wrong letter
    expect(((s['words']! as List).last as Map)['ok'], isFalse);
    expect(g.turn(s), 2);
  });
}
