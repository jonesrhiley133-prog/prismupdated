import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/poll_option.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';

const pollMetaKind = 'poll.meta';

/// How a poll is answered. Stored in a `poll.meta` record whose parentId is
/// the poll id; polls without one are plain [choice] polls.
abstract final class PollType {
  static const choice = 'choice';
  static const yesNo = 'yes_no';
  static const scale = 'scale';
  static const ranked = 'ranked';
  static const rating = 'rating';
  static const all = [choice, yesNo, scale, ranked, rating];

  /// Types that record one vote per option per member.
  static bool perOption(String t) => t == ranked || t == rating;
}

abstract final class PollMetaField {
  static const type = 'type';
  static const scaleMin = 'scaleMin';
  static const scaleMax = 'scaleMax';
  static const category = 'category';
  static const quorum = 'quorum';
}

String pollTypeOf(TrackerRecord? meta) =>
    meta?.str(PollMetaField.type) ?? PollType.choice;

/// Parses `rank:2` / `rating:4` response texts.
int? voteValue(String? response, String prefix) {
  if (response == null || !response.startsWith('$prefix:')) return null;
  return int.tryParse(response.substring(prefix.length + 1));
}

@immutable
class OptionScore {
  const OptionScore({
    required this.option,
    required this.score,
    required this.voters,
    this.average,
  });

  final PollOption option;

  /// Borda points (ranked) or vote count (choice).
  final double score;
  final int voters;

  /// Average rating (rating) or average rank (ranked).
  final double? average;
}

/// Ranked choice by Borda count: with n options, rank 1 earns n points,
/// rank n earns 1. Highest score first.
List<OptionScore> rankedResults(List<PollOption> options) {
  final n = options.length;
  final out = [
    for (final o in options)
      () {
        final ranks = [
          for (final v in o.votes) ?voteValue(v.responseText, 'rank'),
        ];
        return OptionScore(
          option: o,
          score: ranks.fold(0.0, (s, r) => s + (n - r + 1).clamp(0, n)),
          voters: ranks.length,
          average: ranks.isEmpty
              ? null
              : ranks.reduce((a, b) => a + b) / ranks.length,
        );
      }(),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return out;
}

/// Average star rating per option, best first.
List<OptionScore> ratingResults(List<PollOption> options) {
  final out = [
    for (final o in options)
      () {
        final r = [
          for (final v in o.votes) ?voteValue(v.responseText, 'rating'),
        ];
        final avg = r.isEmpty ? null : r.reduce((a, b) => a + b) / r.length;
        return OptionScore(
          option: o,
          score: avg ?? 0,
          voters: r.length,
          average: avg,
        );
      }(),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return out;
}

@immutable
class ScaleSummary {
  const ScaleSummary({
    required this.count,
    this.mean,
    this.median,
    required this.distribution,
  });

  final int count;
  final double? mean;
  final double? median;

  /// Numeric value → votes.
  final Map<int, int> distribution;
}

/// Statistics for a numeric-scale poll whose options are numbers.
ScaleSummary scaleResults(List<PollOption> options) {
  final values = <int>[];
  final dist = <int, int>{};
  for (final o in options) {
    final v = int.tryParse(o.text.trim());
    if (v == null) continue;
    dist[v] = o.votes.length;
    for (var i = 0; i < o.votes.length; i++) {
      values.add(v);
    }
  }
  values.sort();
  double? median;
  if (values.isNotEmpty) {
    final m = values.length ~/ 2;
    median = values.length.isOdd
        ? values[m].toDouble()
        : (values[m - 1] + values[m]) / 2;
  }
  return ScaleSummary(
    count: values.length,
    mean: values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length,
    median: median,
    distribution: dist,
  );
}

/// Distinct members who voted in the poll.
Set<String> voterIds(List<PollOption> options) => {
  for (final o in options)
    for (final v in o.votes) v.memberId,
};

/// Plain-choice winner(s); empty when nobody voted.
List<PollOption> choiceWinners(List<PollOption> options) {
  final top = options.fold<int>(
    0,
    (m, o) => o.votes.length > m ? o.votes.length : m,
  );
  if (top == 0) return const [];
  return [
    for (final o in options)
      if (o.votes.length == top) o,
  ];
}
