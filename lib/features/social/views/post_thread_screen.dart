import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/views/social_nav.dart';
import 'package:prism_plurality/features/social/widgets/post_card.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// A post with its reblogs/answers and nested comment thread.
class PostThreadScreen extends ConsumerStatefulWidget {
  const PostThreadScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostThreadScreen> createState() => _PostThreadScreenState();
}

class _PostThreadScreenState extends ConsumerState<PostThreadScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  Comment? _editing;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String targetId) async {
    final actor = ref.read(socialActorProvider);
    final text = _input.text.trim();
    if (actor == null || text.isEmpty) return;
    final a = ref.read(socialActionsProvider);
    if (_editing != null) {
      await a.editComment(_editing!, text);
    } else {
      await a.comment(actor: actor, targetId: targetId, body: text, replyTo: _replyTo?.id);
    }
    _input.clear();
    setState(() {
      _replyTo = null;
      _editing = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final actor = ref.watch(socialActorProvider);
    final post = d.posts[widget.postId];
    final cb = socialCallbacks(context);
    if (post == null || !d.canSeePost(post, actor)) {
      return PrismPageScaffold(
        topBar: PrismTopBar(title: l10n.socPost, showBackButton: true),
        body: Center(child: Text(post == null ? l10n.socPostGone : l10n.socPostHidden, textAlign: TextAlign.center)),
      );
    }
    final shown = post.reblogOf != null ? (d.original(post) ?? post) : post;
    final comments = d.commentsOn[shown.id] ?? const <Comment>[];
    final visible = [for (final c in comments) if (actor == null || c.author == null || (!d.isBlocked(actor, c.author!) && !d.isMuted(actor, c.author!))) c];
    final children = <String?, List<Comment>>{};
    final ids = {for (final c in visible) c.id};
    for (final c in visible) {
      (children[c.replyTo != null && ids.contains(c.replyTo) ? c.replyTo : null] ??= []).add(c);
    }
    final answers = [for (final s in d.sharesOf[shown.id] ?? const <Post>[]) if (s.quoteOf == shown.id && d.canSeePost(s, actor)) s];

    List<Widget> thread(String? parent, int depth) => [
      for (final c in children[parent] ?? const <Comment>[]) ...[
        _CommentTile(
          comment: c,
          depth: depth,
          onReply: () {
            setState(() {
              _replyTo = c;
              _editing = null;
            });
            _focus.requestFocus();
          },
          onEdit: () {
            setState(() {
              _editing = c;
              _replyTo = null;
              _input.text = c.body;
            });
            _focus.requestFocus();
          },
        ),
        ...thread(c.id, depth + 1),
      ],
    ];

    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.socPost, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PostCard(post: post, callbacks: cb, inDetail: true),
                        if (answers.isNotEmpty) ...[
                          Text(shown.type == PostType.question ? l10n.socAnswersTitle : l10n.socQuotesTitle, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 6),
                          for (final a in answers) PostCard(post: a, callbacks: cb, compact: true),
                        ],
                        Text(l10n.socComments(visible.length), style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(l10n.socNoComments, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ),
                        ...thread(null, 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyTo != null || _editing != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _editing != null ? l10n.socEditingComment : l10n.socReplyingTo(alterName(d, _replyTo!.author, context)),
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            PrismButton(
                              label: l10n.cancel,
                              density: PrismControlDensity.compact,
                              onPressed: () => setState(() {
                                _replyTo = null;
                                _editing = null;
                                _input.clear();
                              }),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          AlterAvatar(memberId: actor, size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PrismTextField(
                              controller: _input,
                              focusNode: _focus,
                              hintText: actor == null ? l10n.socPickAlter : l10n.socCommentAs(alterName(d, actor, context)),
                              minLines: 1,
                              maxLines: 5,
                              enabled: actor != null,
                              onSubmitted: (_) => _send(shown.id),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PrismButton(label: l10n.socSend, tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => _send(shown.id)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment, required this.depth, required this.onReply, required this.onEdit});

  final Comment comment;
  final int depth;
  final VoidCallback onReply;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final actor = ref.watch(socialActorProvider);
    final mine = actor != null && comment.author == actor;
    final indent = (depth.clamp(0, 5)) * 18.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: Container(
        decoration: depth == 0 ? null : BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2))),
        padding: EdgeInsets.only(left: depth == 0 ? 0 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlterAvatar(memberId: comment.author, size: 30, onTap: comment.author == null ? null : () => openAlterBlog(context, comment.author!)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: alterName(d, comment.author, context), style: theme.textTheme.labelLarge),
                        TextSpan(
                          text: '  ${relativeTime(context, comment.at, now: d.now)}${comment.editedAt != null ? ' · ${l10n.socEdited}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichPostText(text: comment.body, style: theme.textTheme.bodyMedium, onTag: (t) => openTag(context, t)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ReactionBar(targetId: comment.id, dense: true),
                      _Link(label: l10n.socReply, onTap: actor == null ? null : onReply),
                      if (mine) _Link(label: l10n.socEdit, onTap: onEdit),
                      if (mine)
                        _Link(
                          label: l10n.delete,
                          onTap: () async {
                            final ok = await PrismDialog.confirm(
                              context: context,
                              title: l10n.socDeleteCommentTitle,
                              confirmLabel: l10n.delete,
                              cancelLabel: l10n.cancel,
                              destructive: true,
                            );
                            if (ok) await ref.read(socialActionsProvider).deleteComment(comment);
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
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: prismCorners(context, 8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
      ),
    ),
  );
}

