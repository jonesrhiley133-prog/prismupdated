import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:drift/drift.dart' show ResultSetImplementation;
import 'package:prism_plurality/core/database/app_database.dart'
    show AppDatabase;
import 'package:prism_plurality/core/database/database_provider.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/polls/advanced/poll_advanced.dart';
import 'package:prism_plurality/features/polls/advanced/poll_advanced_widgets.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/features/trackers/widgets/tracker_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

class PollHistoryRow {
  const PollHistoryRow({
    required this.id,
    required this.question,
    required this.createdAt,
    required this.closed,
    required this.voters,
    required this.votes,
    this.topOption,
  });

  final String id;
  final String question;
  final DateTime createdAt;
  final bool closed;
  final int voters;
  final int votes;
  final String? topOption;
}

class PollStatsData {
  const PollStatsData({required this.polls, required this.pollsByMember});

  final List<PollHistoryRow> polls;

  /// Member id → number of polls they voted in.
  final Map<String, int> pollsByMember;
}

const _pollsSql = '''
SELECT p.id, p.question, p.created_at, p.is_closed, p.expires_at,
  COUNT(DISTINCT pv.member_id) AS voters, COUNT(pv.id) AS votes,
  (SELECT po2.option_text FROM poll_options po2
     LEFT JOIN poll_votes pv2 ON pv2.poll_option_id = po2.id AND pv2.is_deleted = 0
     WHERE po2.poll_id = p.id AND po2.is_deleted = 0
     GROUP BY po2.id HAVING COUNT(pv2.id) > 0
     ORDER BY COUNT(pv2.id) DESC LIMIT 1) AS top_option
FROM polls p
LEFT JOIN poll_options po ON po.poll_id = p.id AND po.is_deleted = 0
LEFT JOIN poll_votes pv ON pv.poll_option_id = po.id AND pv.is_deleted = 0
WHERE p.is_deleted = 0
GROUP BY p.id
ORDER BY p.created_at DESC
''';

const _membersSql = '''
SELECT pv.member_id AS member_id, COUNT(DISTINCT po.poll_id) AS polls
FROM poll_votes pv
JOIN poll_options po ON po.id = pv.poll_option_id AND po.is_deleted = 0
JOIN polls p ON p.id = po.poll_id AND p.is_deleted = 0
WHERE pv.is_deleted = 0
GROUP BY pv.member_id
''';

Stream<PollStatsData> watchPollStats(AppDatabase db) {
  final tables = <ResultSetImplementation<dynamic, dynamic>>{
    db.polls,
    db.pollOptions,
    db.pollVotes,
  };
  return db.customSelect(_pollsSql, readsFrom: tables).watch().asyncMap((
    rows,
  ) async {
    final now = DateTime.now();
    final members = await db.customSelect(_membersSql, readsFrom: tables).get();
    return PollStatsData(
      polls: [
        for (final r in rows)
          PollHistoryRow(
            id: r.read<String>('id'),
            question: r.read<String>('question'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r.read<int>('created_at') * 1000,
            ),
            closed:
                r.read<bool>('is_closed') ||
                (r.read<int?>('expires_at') != null &&
                    DateTime.fromMillisecondsSinceEpoch(
                      r.read<int>('expires_at') * 1000,
                    ).isBefore(now)),
            voters: r.read<int>('voters'),
            votes: r.read<int>('votes'),
            topOption: r.read<String?>('top_option'),
          ),
      ],
      pollsByMember: {
        for (final m in members)
          m.read<String>('member_id'): m.read<int>('polls'),
      },
    );
  });
}

final pollStatsProvider = StreamProvider<PollStatsData>(
  (ref) => watchPollStats(ref.watch(databaseProvider)),
);

/// Poll history, participation per member and categories.
class PollStatsScreen extends ConsumerStatefulWidget {
  const PollStatsScreen({super.key});

  @override
  ConsumerState<PollStatsScreen> createState() => _PollStatsScreenState();
}

class _PollStatsScreenState extends ConsumerState<PollStatsScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(pollStatsProvider);
    final members = ref.watch(activeMembersProvider).value ?? const <Member>[];
    final metas = {
      for (final r
          in ref.watch(trackerRecordsProvider).value ?? const <TrackerRecord>[])
        if (r.kind == pollMetaKind && r.parentId != null) r.parentId!: r,
    };
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.pollStatsTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (data) {
          final categories = {
            for (final m in metas.values) ?m.str(PollMetaField.category),
          }.toList()..sort();
          final polls = [
            for (final p in data.polls)
              if (_category == null ||
                  metas[p.id]?.str(PollMetaField.category) == _category)
                p,
          ];
          final withVotes = polls.where((p) => p.voters > 0).toList();
          final avgTurnout = members.isEmpty || polls.isEmpty
              ? null
              : polls.fold(0, (s, p) => s + p.voters) /
                    polls.length /
                    members.length;
          final byType = <String, int>{};
          for (final p in polls) {
            final t = pollTypeOf(metas[p.id]);
            byType[t] = (byType[t] ?? 0) + 1;
          }
          final participation = [
            for (final m in members) (m, data.pollsByMember[m.id] ?? 0),
          ]..sort((a, b) => b.$2.compareTo(a.$2));
          final children = <Widget>[
            TrackerStatGrid(
              children: [
                TrackerStatTile(
                  label: l10n.pollStatTotal,
                  value: '${polls.length}',
                  icon: AppIcons.navPolls,
                ),
                TrackerStatTile(
                  label: l10n.pollStatOpen,
                  value: '${polls.where((p) => !p.closed).length}',
                ),
                TrackerStatTile(
                  label: l10n.pollStatVotes,
                  value: '${polls.fold(0, (s, p) => s + p.votes)}',
                ),
                TrackerStatTile(
                  label: l10n.pollStatTurnout,
                  value: avgTurnout == null
                      ? '–'
                      : '${(avgTurnout * 100).round()}%',
                ),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PrismChip(
                    label: l10n.journalFilterAll,
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    PrismChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            ],
            TrackerLabel(l10n.pollParticipation),
            if (participation.isEmpty)
              Text(l10n.pollNoMembers, style: theme.textTheme.bodySmall),
            for (final (m, n) in participation)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(memberLabel(m))),
                        Text(
                          l10n.pollVotedIn(n, data.polls.length),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    TrackerBar(
                      value: data.polls.isEmpty ? 0 : n / data.polls.length,
                    ),
                  ],
                ),
              ),
            if (byType.isNotEmpty) ...[
              TrackerLabel(l10n.pollByType),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in byType.entries)
                    PrismChip(
                      label: '${pollTypeLabel(l10n, e.key)} · ${e.value}',
                      selected: false,
                      onTap: () {},
                    ),
                ],
              ),
            ],
            TrackerLabel(l10n.pollHistory(withVotes.length)),
            if (polls.isEmpty)
              Text(l10n.pollNoPolls, style: theme.textTheme.bodySmall),
            for (final p in polls)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: PrismSurface(
                  onTap: () => context.push(AppRoutePaths.poll(p.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.question, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          DateFormat.yMMMd(
                            context.dateLocale,
                          ).format(p.createdAt),
                          p.closed ? l10n.pollsClosed : l10n.pollStatOpen,
                          pollTypeLabel(l10n, pollTypeOf(metas[p.id])),
                          ?metas[p.id]?.str(PollMetaField.category),
                          l10n.pollVoters(p.voters),
                          if (p.topOption != null &&
                              pollTypeOf(metas[p.id]) == PollType.choice)
                            l10n.pollLeading(p.topOption!),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: PrismTokens.contentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
