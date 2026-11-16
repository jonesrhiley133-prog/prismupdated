import 'package:prism_plurality/shared/widgets/section_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/views/compose_post_sheet.dart';
import 'package:prism_plurality/features/social/views/social_nav.dart';
import 'package:prism_plurality/features/social/widgets/post_card.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/stories_row.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum _Tab { feed, explore, activity }

/// Unread activity for the alter being acted as (tab badge).
final socialUnreadProvider = Provider<int>((ref) {
  final actor = ref.watch(socialActorProvider);
  if (actor == null) return 0;
  return ref.watch(socialDataProvider.select((d) => d.unreadCount(actor)));
});

/// The in-system social space: feeds, explore, activity, and the classic
/// message board.
class BulletinScreen extends ConsumerStatefulWidget {
  const BulletinScreen({super.key});

  @override
  ConsumerState<BulletinScreen> createState() => _BulletinScreenState();
}

class _BulletinScreenState extends ConsumerState<BulletinScreen> {
  _Tab _tab = _Tab.feed;
  String _mode = 'forYou';
  String _query = '';

  Widget _wrap(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children,
              SizedBox(height: NavBarInset.of(context) + 90),
            ],
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loaded = ref.watch(socialLoadedProvider);
    final unread = ref.watch(socialUnreadProvider);
    final cb = socialCallbacks(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.socBoardTitle,
        actions: [
          PrismTopBarAction(
            icon: Icons.forum_outlined,
            tooltip: l10n.socMessages,
            onPressed: () => context.push(AppRoutePaths.boardMessages),
          ),
          PrismTopBarAction(
            icon: Icons.drafts_outlined,
            tooltip: l10n.socDraftsScheduled,
            onPressed: () => context.push(AppRoutePaths.socialDrafts),
          ),
          PrismTopBarAction(
            icon: Icons.edit_square,
            tooltip: l10n.socNewPost,
            onPressed: () => showComposePost(context),
          ),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: !loaded
          ? const PrismLoadingState()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: PrismTokens.contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: ActorChip(),
                          ),
                          const SizedBox(height: 8),
                          PrismSegmentedControl<_Tab>(
                            segments: [
                              PrismSegment(
                                value: _Tab.feed,
                                label: l10n.socFeed,
                              ),
                              PrismSegment(
                                value: _Tab.explore,
                                label: l10n.socExplore,
                              ),
                              PrismSegment(
                                value: _Tab.activity,
                                label: unread == 0
                                    ? l10n.socActivity
                                    : l10n.socActivityN(unread),
                              ),
                            ],
                            selected: _tab,
                            onChanged: (v) {
                              setState(() => _tab = v);
                              if (v == _Tab.activity) {
                                final actor = ref.read(socialActorProvider);
                                // Mark read when leaving the tab, so the list
                                // still shows what was new on arrival.
                                if (actor != null)
                                  Future<void>.delayed(
                                    const Duration(seconds: 2),
                                    () => ref
                                        .read(socialActionsProvider)
                                        .markSeen(actor),
                                  );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SectionSwitcher(
                    id: _tab,
                    child: switch (_tab) {
                      _Tab.feed => _feed(context, cb),
                      _Tab.explore => _explore(context, cb),
                      _Tab.activity => _wrap([const ActivityList()]),
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _feed(BuildContext context, PostCallbacks cb) {
    final l10n = context.l10n;
    final actor = ref.watch(socialActorProvider);
    final posts = ref.watch(
      socialDataProvider.select((d) => d.feed(actor, mode: _mode)),
    );
    return _wrap([
      const StoriesRow(),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        children: [
          PrismChip(
            label: l10n.socForYou,
            selected: _mode == 'forYou',
            onTap: () => setState(() => _mode = 'forYou'),
          ),
          PrismChip(
            label: l10n.socFollowing,
            selected: _mode == 'following',
            onTap: () => setState(() => _mode = 'following'),
          ),
          PrismChip(
            label: l10n.socLatest,
            selected: _mode == 'everything',
            onTap: () => setState(() => _mode = 'everything'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (posts.isEmpty)
        _Empty(
          icon: Icons.dynamic_feed_outlined,
          title: _mode == 'following'
              ? l10n.socEmptyFollowing
              : l10n.socEmptyFeed,
          message: _mode == 'following'
              ? l10n.socEmptyFollowingHelp
              : l10n.socEmptyFeedHelp,
          action: PrismButton(
            label: l10n.socNewPost,
            tone: PrismButtonTone.filled,
            onPressed: () => showComposePost(context),
          ),
        ),
      for (final p in posts) PostCard(post: p, callbacks: cb),
    ]);
  }

  Widget _explore(BuildContext context, PostCallbacks cb) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actor = ref.watch(socialActorProvider);
    final d = ref.watch(socialDataProvider);
    final results = _query.trim().isEmpty
        ? const <Post>[]
        : d.feed(actor, query: _query);
    final tags = d.trendingTags(actor).take(20).toList();
    final alters =
        d.members.values.where((m) => m.isActive && !m.isDeleted).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return _wrap([
      PrismTextField(
        hintText: l10n.socSearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        onChanged: (v) => setState(() => _query = v),
      ),
      const SizedBox(height: 12),
      if (_query.trim().isNotEmpty) ...[
        Text(
          l10n.socResults(results.length),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final p in results)
          PostCard(post: p, callbacks: cb, compact: true),
      ] else ...[
        Text(l10n.socAlters, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final m in alters)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        AlterAvatar(
                          memberId: m.id,
                          size: 52,
                          onTap: () => openAlterBlog(context, m.id),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.socTrendingTags, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text(
            l10n.socNoTags,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (t, n) in tags)
              PrismChip(
                label: '#$t · $n',
                selected: false,
                onTap: () => openTag(context, t),
              ),
          ],
        ),
        if (d.reports.isNotEmpty) ...[
          const SizedBox(height: 16),
          PrismSurface(
            onTap: () => context.push(AppRoutePaths.socialReports),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.socReportsToReview(d.reports.length)),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ],
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Notifications for the alter being acted as.
class ActivityList extends ConsumerWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actor = ref.watch(socialActorProvider);
    final d = ref.watch(socialDataProvider);
    if (actor == null)
      return _Empty(icon: Icons.person_outline, title: l10n.socPickAlter);
    final items = d.notifications(actor).take(150).toList();
    final since = d.lastSeen(actor);
    if (items.isEmpty)
      return _Empty(
        icon: Icons.notifications_none_rounded,
        title: l10n.socNoActivity,
        message: l10n.socNoActivityHelp,
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PrismSurface(
              tone: n.at.isAfter(since)
                  ? PrismSurfaceTone.accent
                  : PrismSurfaceTone.subtle,
              padding: const EdgeInsets.all(12),
              onTap: () {
                final t = n.targetId;
                if (n.kind == 'follow') {
                  openAlterBlog(context, n.actor);
                } else if (t != null && d.posts.containsKey(t)) {
                  openPost(context, t);
                } else if (t != null && d.stories.containsKey(t)) {
                  openAlterBlog(context, actor);
                }
              },
              child: Row(
                children: [
                  AlterAvatar(memberId: n.actor, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _describe(context, n, alterName(d, n.actor, context)),
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (n.detail != null &&
                            n.detail!.isNotEmpty &&
                            !n.kind.startsWith('react'))
                          Text(
                            n.detail!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          relativeTime(context, n.at, now: d.now),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _describe(BuildContext context, SocialNotification n, String who) {
    final l10n = context.l10n;
    return switch (n.kind) {
      'reactPost' => l10n.socNReactPost(who, n.detail ?? ''),
      'reactComment' => l10n.socNReactComment(who, n.detail ?? ''),
      'reactStory' => l10n.socNReactStory(who, n.detail ?? ''),
      'comment' => l10n.socNComment(who),
      'reply' => l10n.socNReply(who),
      'storyReply' => l10n.socNStoryReply(who),
      'reblog' => l10n.socNReblog(who),
      'quote' => l10n.socNQuote(who),
      'mention' => l10n.socNMention(who),
      'question' => l10n.socNQuestion(who),
      'follow' => l10n.socNFollow(who),
      _ => l10n.socNVote(who),
    };
  }
}

/// Posts with a tag.
class TagScreen extends ConsumerWidget {
  const TagScreen({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actor = ref.watch(socialActorProvider);
    final posts = ref.watch(
      socialDataProvider.select((d) => d.feed(actor, tag: tag)),
    );
    final cb = socialCallbacks(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: '#${normalizeTag(tag)}', showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (posts.isEmpty)
                    _Empty(icon: Icons.tag_rounded, title: l10n.socNoTagPosts),
                  for (final p in posts) PostCard(post: p, callbacks: cb),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drafts and scheduled posts of the alter being acted as.
class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actor = ref.watch(socialActorProvider);
    final d = ref.watch(socialDataProvider);
    final drafts = actor == null ? const <Post>[] : d.drafts(actor);
    final scheduled = actor == null ? const <Post>[] : d.scheduled(actor);
    final cb = socialCallbacks(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.socDraftsScheduled, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ActorChip(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.socScheduledTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  if (scheduled.isEmpty)
                    Text(
                      l10n.socNoScheduled,
                      style: theme.textTheme.bodyMedium,
                    ),
                  for (final p in scheduled)
                    PostCard(
                      post: p,
                      callbacks: cb,
                      compact: true,
                      inDetail: true,
                    ),
                  const SizedBox(height: 16),
                  Text(l10n.socDraftsTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (drafts.isEmpty)
                    Text(l10n.socNoDrafts, style: theme.textTheme.bodyMedium),
                  for (final p in drafts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrismSurface(
                        onTap: () => showComposePost(context, edit: p),
                        child: Row(
                          children: [
                            const Icon(Icons.drafts_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.title.isNotEmpty
                                    ? p.title
                                    : (p.body.isEmpty
                                          ? l10n.socUntitledDraft
                                          : p.body),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              relativeTime(context, p.r.modifiedAt, now: d.now),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Posts alters reported, for the system to review.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final cb = socialCallbacks(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.socReportsTitle, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: PrismTokens.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.socReportsHelp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (d.reports.isEmpty)
                    _Empty(icon: Icons.flag_outlined, title: l10n.socNoReports),
                  for (final r in d.reports)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.socReportedBy(
                              alterName(d, r.memberId, context),
                              r.body ?? '',
                            ),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          if (d.posts[r.parentId] != null)
                            PostCard(
                              post: d.posts[r.parentId]!,
                              callbacks: cb,
                              compact: true,
                            )
                          else
                            Text(l10n.socPostGone),
                          Wrap(
                            spacing: 8,
                            children: [
                              PrismButton(
                                label: l10n.socDismissReport,
                                density: PrismControlDensity.compact,
                                onPressed: () => ref
                                    .read(socialActionsProvider)
                                    .resolveReport(r),
                              ),
                              if (d.posts[r.parentId] != null)
                                PrismButton(
                                  label: l10n.socDeletePost,
                                  tone: PrismButtonTone.destructive,
                                  density: PrismControlDensity.compact,
                                  onPressed: () async {
                                    await ref
                                        .read(socialActionsProvider)
                                        .deletePost(r.parentId!);
                                    await ref
                                        .read(socialActionsProvider)
                                        .resolveReport(r);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
