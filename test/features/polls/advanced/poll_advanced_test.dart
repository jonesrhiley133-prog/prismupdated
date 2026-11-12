import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/poll_option.dart';
import 'package:prism_plurality/domain/models/poll_vote.dart';
import 'package:prism_plurality/features/polls/advanced/poll_advanced.dart';

PollVote _v(String m, String? r) =>
    PollVote(id: '$m$r', memberId: m, votedAt: DateTime(2026), responseText: r);

void main() {
  test('ranked choice uses Borda points', () {
    final opts = [
      PollOption(
        id: 'a',
        text: 'Pizza',
        votes: [_v('m1', 'rank:1'), _v('m2', 'rank:2'), _v('m3', 'rank:1')],
      ),
      PollOption(
        id: 'b',
        text: 'Tacos',
        votes: [_v('m1', 'rank:2'), _v('m2', 'rank:1'), _v('m3', 'rank:3')],
      ),
      PollOption(
        id: 'c',
        text: 'Soup',
        votes: [_v('m1', 'rank:3'), _v('m2', 'rank:3'), _v('m3', 'rank:2')],
      ),
    ];
    final r = rankedResults(opts);
    expect(r.map((s) => (s.option.text, s.score)), [
      ('Pizza', 8.0),
      ('Tacos', 6.0),
      ('Soup', 4.0),
    ]);
    expect(r.first.average, closeTo(1.33, 0.01));
  });

  test('ratings average per option; scale stats; choice winners', () {
    final rated = ratingResults([
      PollOption(
        id: 'a',
        text: 'A',
        votes: [_v('m1', 'rating:4'), _v('m2', 'rating:2')],
      ),
      PollOption(id: 'b', text: 'B', votes: [_v('m1', 'rating:5')]),
      const PollOption(id: 'c', text: 'C'),
    ]);
    expect(rated.map((s) => s.option.text), ['B', 'A', 'C']);
    expect(rated[1].average, 3);
    final s = scaleResults([
      PollOption(id: '1', text: '1', votes: [_v('m1', null)]),
      const PollOption(id: '2', text: '2'),
      PollOption(id: '3', text: '3', votes: [_v('m2', null), _v('m3', null)]),
      PollOption(id: '5', text: '5', votes: [_v('m4', null)]),
    ]);
    expect((s.count, s.mean, s.median), (4, 3.0, 3.0));
    expect(s.distribution, {1: 1, 2: 0, 3: 2, 5: 1});
    final tie = [
      PollOption(id: 'x', text: 'X', votes: [_v('m1', null)]),
      PollOption(id: 'y', text: 'Y', votes: [_v('m2', null)]),
    ];
    expect(choiceWinners(tie), hasLength(2));
    expect(choiceWinners(const [PollOption(id: 'z', text: 'Z')]), isEmpty);
    expect(voterIds(tie), {'m1', 'm2'});
    expect(voteValue('rank:3', 'rank'), 3);
    expect(voteValue('rating:x', 'rating'), isNull);
    expect(PollType.perOption(PollType.ranked), isTrue);
  });
}
