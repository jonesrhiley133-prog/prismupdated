import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/poll.dart';
import 'package:prism_plurality/domain/models/poll_option.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/polls/advanced/poll_advanced.dart';
import 'package:prism_plurality/features/polls/models/cast_poll_vote_command.dart';
import 'package:prism_plurality/features/polls/providers/poll_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';

/// The `poll.meta` record for a poll, if any.
final pollMetaProvider = Provider.family<TrackerRecord?, String>((ref, pollId) {
  final all =
      ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[];
  for (final r in all) {
    if (r.kind == pollMetaKind && r.parentId == pollId) return r;
  }
  return null;
});

String pollTypeLabel(AppLocalizations l10n, String t) => switch (t) {
  PollType.yesNo => l10n.pollTypeYesNo,
  PollType.scale => l10n.pollTypeScale,
  PollType.ranked => l10n.pollTypeRanked,
  PollType.rating => l10n.pollTypeRating,
  _ => l10n.pollTypeChoice,
};

String pollTypeHelp(AppLocalizations l10n, String t) => switch (t) {
  PollType.yesNo => l10n.pollTypeYesNoHelp,
  PollType.scale => l10n.pollTypeScaleHelp,
  PollType.ranked => l10n.pollTypeRankedHelp,
  PollType.rating => l10n.pollTypeRatingHelp,
  _ => l10n.pollTypeChoiceHelp,
};

/// Voting UI for ranked-choice and rating polls: one vote per option,
/// cast as the member chosen in "Voting as".
class PerOptionVoting extends ConsumerStatefulWidget {
  const PerOptionVoting({
    super.key,
    required this.poll,
    required this.options,
    required this.type,
    required this.closed,
  });

  final Poll poll;
  final List<PollOption> options;
  final String type;
  final bool closed;

  @override
  ConsumerState<PerOptionVoting> createState() => _PerOptionVotingState();
}

class _PerOptionVotingState extends ConsumerState<PerOptionVoting> {
  List<String>? _order;
  final Map<String, int> _ratings = {};
  String? _loadedFor;
  bool _busy = false;

  String get _prefix => widget.type == PollType.ranked ? 'rank' : 'rating';

  void _loadFor(String? memberId) {
    if (_loadedFor == memberId && _order != null) return;
    _loadedFor = memberId;
    final mine = <String, int>{};
    for (final o in widget.options) {
      for (final v in o.votes) {
        if (v.memberId == memberId) {
          final n = voteValue(v.responseText, _prefix);
          if (n != null) mine[o.id] = n;
        }
      }
    }
    if (widget.type == PollType.ranked) {
      final ids = [for (final o in widget.options) o.id];
      ids.sort((a, b) => (mine[a] ?? 999).compareTo(mine[b] ?? 999));
      _order = ids;
    } else {
      _order = const [];
      _ratings
        ..clear()
        ..addAll(mine);
    }
  }

  Future<void> _submit(String memberId) async {
    setState(() => _busy = true);
    final svc = ref.read(pollMutationServiceProvider);
    if (widget.type == PollType.ranked) {
      for (var i = 0; i < _order!.length; i++) {
        await svc.castVote(
          CastPollVoteCommand(
            pollId: widget.poll.id,
            optionId: _order![i],
            memberId: memberId,
            responseText: 'rank:${i + 1}',
          ),
        );
      }
    } else {
      for (final o in widget.options) {
        final r = _ratings[o.id];
        if (r != null) {
          await svc.castVote(
            CastPollVoteCommand(
              pollId: widget.poll.id,
              optionId: o.id,
              memberId: memberId,
              responseText: 'rating:$r',
            ),
          );
        } else {
          for (final v in o.votes.where((v) => v.memberId == memberId)) {
            await svc.removeVote(v.id);
          }
        }
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final memberId = ref.watch(votingAsProvider);
    _loadFor(memberId);
    final byId = {for (final o in widget.options) o.id: o};
    if (widget.closed || memberId == null) {
      return Text(
        memberId == null && !widget.closed
            ? l10n.pollChooseVoter
            : l10n.pollClosedSeeResults,
        style: theme.textTheme.bodySmall,
      );
    }
    if (widget.type == PollType.ranked) {
      final order = _order!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pollRankHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          for (var i = 0; i < order.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: PrismSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}.',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Expanded(child: Text(byId[order[i]]?.text ?? '')),
                    IconButton(
                      tooltip: l10n.trackerMoveUp,
                      icon: Icon(AppIcons.arrowUpward, size: 18),
                      onPressed: i == 0
                          ? null
                          : () => setState(
                              () => order.insert(i - 1, order.removeAt(i)),
                            ),
                    ),
                    IconButton(
                      tooltip: l10n.pollMoveDown,
                      icon: Icon(AppIcons.arrowDownward, size: 18),
                      onPressed: i == order.length - 1
                          ? null
                          : () => setState(
                              () => order.insert(i + 1, order.removeAt(i)),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          PrismButton(
            label: l10n.pollsDetailSubmitVote,
            tone: PrismButtonTone.filled,
            expanded: true,
            isLoading: _busy,
            enabled: !_busy,
            onPressed: () => _submit(memberId),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.pollRateHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final o in widget.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PrismSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.text, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var s = 1; s <= 5; s++)
                        PrismChip(
                          label: '$s★',
                          selected: _ratings[o.id] == s,
                          onTap: () => setState(
                            () => _ratings[o.id] == s
                                ? _ratings.remove(o.id)
                                : _ratings[o.id] = s,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        PrismButton(
          label: l10n.pollsDetailSubmitVote,
          tone: PrismButtonTone.filled,
          expanded: true,
          isLoading: _busy,
          enabled: !_busy && _ratings.isNotEmpty,
          onPressed: () => _submit(memberId),
        ),
      ],
    );
  }
}

/// Results and participation for any poll type.
class PollAnalyticsCard extends ConsumerWidget {
  const PollAnalyticsCard({
    super.key,
    required this.poll,
    required this.options,
    required this.type,
  });

  final Poll poll;
  final List<PollOption> options;
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final voters = voterIds(options);
    final turnout = members.isEmpty
        ? null
        : voters.where((id) => members.any((m) => m.id == id)).length /
              members.length;
    final missing = [
      for (final m in members)
        if (!voters.contains(m.id)) m,
    ];
    final rows = <Widget>[];
    switch (type) {
      case PollType.ranked:
        final r = rankedResults(options);
        final maxScore = r.isEmpty
            ? 1.0
            : (r.first.score == 0 ? 1.0 : r.first.score);
        for (final s in r) {
          rows.add(
            _bar(
              context,
              s.option.text,
              s.score / maxScore,
              l10n.pollBordaPoints(
                s.score.round(),
                s.average?.toStringAsFixed(1) ?? '–',
              ),
            ),
          );
        }
      case PollType.rating:
        for (final s in ratingResults(options)) {
          rows.add(
            _bar(
              context,
              s.option.text,
              (s.average ?? 0) / 5,
              s.average == null
                  ? l10n.pollNoRatings
                  : l10n.pollAverageRating(
                      s.average!.toStringAsFixed(1),
                      s.voters,
                    ),
            ),
          );
        }
      case PollType.scale:
        final s = scaleResults(options);
        rows.add(
          Text(
            s.count == 0
                ? l10n.pollNoVotesYet
                : l10n.pollScaleSummary(
                    s.mean!.toStringAsFixed(1),
                    s.median!.toStringAsFixed(1),
                    s.count,
                  ),
            style: theme.textTheme.titleSmall,
          ),
        );
        final maxCount = s.distribution.values.fold<int>(
          1,
          (m, v) => v > m ? v : m,
        );
        for (final e
            in (s.distribution.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key)))) {
          rows.add(_bar(context, '${e.key}', e.value / maxCount, '${e.value}'));
        }
      default:
        final total = options.fold<int>(0, (s, o) => s + o.votes.length);
        final winners = choiceWinners(options);
        if (winners.isNotEmpty) {
          rows.add(
            Text(
              winners.length == 1
                  ? l10n.pollLeading(winners.first.text)
                  : l10n.pollTied(winners.map((w) => w.text).join(', ')),
              style: theme.textTheme.titleSmall,
            ),
          );
        }
        for (final o in options) {
          rows.add(
            _bar(
              context,
              o.text,
              total == 0 ? 0 : o.votes.length / total,
              total == 0
                  ? '0'
                  : '${o.votes.length} · ${(o.votes.length * 100 / total).round()}%',
            ),
          );
        }
    }
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pollAnalytics, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            [
              pollTypeLabel(l10n, type),
              l10n.pollVoters(voters.length),
              if (turnout != null) l10n.pollTurnout((turnout * 100).round()),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...rows,
          if (!poll.isAnonymous && missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.pollNotVotedYet(missing.map(memberLabel).join(', ')),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double v, String trailing) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(trailing, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 3),
            TrackerBar(value: v),
          ],
        ),
      );
}

/// Saves the meta record for a new poll.
Future<void> savePollMeta(
  TrackerNotifier n, {
  required String pollId,
  required String type,
  String? category,
  int? scaleMin,
  int? scaleMax,
}) async {
  if (type == PollType.choice && (category == null || category.isEmpty)) return;
  await n.create(
    kind: pollMetaKind,
    parentId: pollId,
    title: type,
    fields: {
      PollMetaField.type: type,
      PollMetaField.category: category == null || category.isEmpty
          ? null
          : category,
      PollMetaField.scaleMin: scaleMin,
      PollMetaField.scaleMax: scaleMax,
    },
  );
}
