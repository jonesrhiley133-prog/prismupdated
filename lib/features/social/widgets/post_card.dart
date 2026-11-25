import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/accessibility/a11y_views.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/video_tile.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';

/// Hooks the feed screens give a card (navigation lives with the screens).
class PostCallbacks {
  const PostCallbacks({required this.openPost, required this.openAlter, required this.openTag, required this.compose});

  final void Function(String postId) openPost;
  final void Function(String memberId) openAlter;
  final void Function(String tag) openTag;

  /// Open the composer: to quote, edit or answer.
  final void Function({Post? quote, Post? edit, Post? answer}) compose;
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.callbacks, this.compact = false, this.inDetail = false});

  final Post post;
  final PostCallbacks callbacks;
  final bool compact;
  final bool inDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final actor = ref.watch(socialActorProvider);
    final isReblog = post.reblogOf != null;
    final shown = isReblog ? (d.original(post) ?? post) : post;
    final quoted = shown.quoteOf == null ? null : d.posts[shown.quoteOf!];
    final comments = d.commentsOn[shown.id]?.length ?? 0;
    final shares = d.sharesOf[shown.id]?.length ?? 0;
    final accent = d.profile(shown.author ?? '').accent;

    Widget header(Post p, {bool small = false}) => Row(
      children: [
        AlterAvatar(memberId: p.author, size: small ? 28 : 40, onTap: p.author == null ? null : () => callbacks.openAlter(p.author!)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alterName(d, p.author, context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (small ? theme.textTheme.labelLarge : theme.textTheme.titleSmall)?.copyWith(color: accent == null ? null : Color(accent)),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      [
                        relativeTime(context, p.publishedAt, now: d.now),
                        if (p.editedAt != null) l10n.socEdited,
                        if (p.status == PostStatus.scheduled && p.publishedAt.isAfter(d.now)) l10n.socScheduled,
                        if (p.status == PostStatus.draft) l10n.socDraft,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(label: audienceLabel(context, p.audience), child: Icon(audienceIcon(p.audience), size: 13, color: theme.colorScheme.onSurfaceVariant)),
                  if (p.pinned) ...[const SizedBox(width: 4), Semantics(label: l10n.socPinned, child: Icon(Icons.push_pin_rounded, size: 13, color: theme.colorScheme.primary))],
                ],
              ),
            ],
          ),
        ),
        if (!small)
          Semantics(
            button: true,
            label: l10n.socPostOptions,
            excludeSemantics: true,
            child: InkResponse(
              radius: 20,
              onTap: () => showPostMenu(context, ref, post, callbacks),
              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_horiz_rounded)),
            ),
          ),
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isReblog)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.repeat_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.socRebloggedBy(alterName(d, post.author, context), alterName(d, shown.author, context)),
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.socPostOptions,
                  excludeSemantics: true,
                  child: InkResponse(radius: 18, onTap: () => showPostMenu(context, ref, post, callbacks), child: const Icon(Icons.more_horiz_rounded, size: 20)),
                ),
              ],
            ),
          ),
        if (isReblog && post.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichPostText(text: post.body, onTag: callbacks.openTag),
          ),
        header(shown),
        const SizedBox(height: 10),
        _Body(post: shown, callbacks: callbacks, compact: compact),
        if (quoted != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              label: l10n.socQuoting(alterName(d, quoted.author, context)),
              child: GestureDetector(
                onTap: () => callbacks.openPost(quoted.id),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(borderRadius: prismCorners(context, 14), border: Border.all(color: theme.colorScheme.outlineVariant)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header(quoted, small: true), const SizedBox(height: 6), _Body(post: quoted, callbacks: callbacks, compact: true)],
                  ),
                ),
              ),
            ),
          )
        else if (shown.quoteOf != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.socOriginalGone, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ),
        if (shown.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in shown.tags)
                  Semantics(
                    link: true,
                    label: l10n.socTagLabel(t),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => callbacks.openTag(t),
                      child: Text('#$t', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        ReactionBar(targetId: shown.id),
        const SizedBox(height: 6),
        Row(
          children: [
            _Action(
              icon: Icons.mode_comment_outlined,
              label: l10n.socComments(comments),
              text: comments == 0 ? null : '$comments',
              onTap: inDetail ? null : () => callbacks.openPost(shown.id),
            ),
            _Action(
              icon: Icons.repeat_rounded,
              label: l10n.socReblogs(shares),
              text: shares == 0 ? null : '$shares',
              onTap: actor == null ? null : () => _share(context, ref, shown),
            ),
            if (shown.type == PostType.question && (shown.askedTo == null || shown.askedTo == actor))
              _Action(icon: Icons.question_answer_outlined, label: l10n.socAnswer, text: l10n.socAnswer, onTap: () => callbacks.compose(answer: shown)),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PrismSurface(
        padding: EdgeInsets.all(compact ? 12 : 14),
        onTap: inDetail ? null : () => callbacks.openPost(post.id),
        child: content,
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref, Post shown) async {
    final l10n = context.l10n;
    final actor = ref.read(socialActorProvider);
    if (actor == null) return;
    final choice = await PrismSheet.show<String>(
      context: context,
      title: l10n.socShare,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuRow(icon: Icons.repeat_rounded, label: l10n.socReblog, hint: l10n.socReblogHelp, onTap: () => Navigator.of(sheet).pop('reblog')),
            MenuRow(icon: Icons.edit_note_rounded, label: l10n.socReblogComment, onTap: () => Navigator.of(sheet).pop('comment')),
            MenuRow(icon: Icons.format_quote_rounded, label: l10n.socQuote, hint: l10n.socQuoteHelp, onTap: () => Navigator.of(sheet).pop('quote')),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    final a = ref.read(socialActionsProvider);
    if (choice == 'reblog') {
      await a.reblog(actor: actor, post: shown);
      if (context.mounted) PrismToast.success(context, message: l10n.socReblogged);
    } else if (choice == 'comment') {
      final text = await askText(context, title: l10n.socReblogComment, label: l10n.socYourComment);
      if (text == null) return;
      await a.reblog(actor: actor, post: shown, comment: text);
      if (context.mounted) PrismToast.success(context, message: l10n.socReblogged);
    } else {
      callbacks.compose(quote: shown);
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.text});

  final IconData icon;
  final String label;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: prismCorners(context, 18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              if (text != null) ...[const SizedBox(width: 6), Text(text!, style: theme.textTheme.labelMedium)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.post, required this.callbacks, required this.compact});

  final Post post;
  final PostCallbacks callbacks;
  final bool compact;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = widget.post;
    final cw = p.contentWarning;
    if (cw != null && !_revealed) {
      return Semantics(
        button: true,
        label: l10n.socCwLabel(cw),
        hint: l10n.socTapToShow,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: prismCorners(context, 12),
          onTap: () => setState(() => _revealed = true),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: prismCorners(context, 12), color: theme.colorScheme.errorContainer.withValues(alpha: 0.5)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.socCwLabel(cw), style: theme.textTheme.bodyMedium)),
                Text(l10n.socShow, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      );
    }
    final d = ref.watch(socialDataProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.type == PostType.question)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: prismCorners(context, 14), color: theme.colorScheme.primary.withValues(alpha: 0.10)),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.askedTo == null ? l10n.socAskedEveryone : l10n.socAskedTo(alterName(d, p.askedTo, context)),
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        if (p.title.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p.title, style: theme.textTheme.titleLarge)),
        if (p.body.isNotEmpty) RichPostText(text: p.body, onTag: widget.callbacks.openTag, maxLines: widget.compact ? 8 : null),
        if (p.images.isNotEmpty) ...[const SizedBox(height: 8), _Gallery(ids: p.images)],
        if (p.video != null) ...[const SizedBox(height: 8), VideoTile(id: p.video!)],
        if (p.type == PostType.poll && p.pollOptions.isNotEmpty) ...[const SizedBox(height: 8), _Poll(post: p)],
        if (p.type == PostType.question) _Answers(post: p, callbacks: widget.callbacks),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    void open(int i) => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ImageGalleryScreen(ids: ids, initial: i)));
    if (ids.length == 1) {
      return ClipRRect(
        borderRadius: prismCorners(context, 14),
        child: GestureDetector(
          onTap: () => open(0),
          child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: SocialImage(id: ids.first, fit: BoxFit.cover, width: double.infinity)),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cols = ids.length == 2 || ids.length == 4 ? 2 : 3;
        final size = (box.maxWidth - (cols - 1) * 4) / cols;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < ids.length; i++)
              GestureDetector(
                onTap: () => open(i),
                child: ClipRRect(borderRadius: prismCorners(context, 10), child: SocialImage(id: ids[i], width: size, height: size)),
              ),
          ],
        );
      },
    );
  }
}

class ImageGalleryScreen extends StatelessWidget {
  const ImageGalleryScreen({super.key, required this.ids, this.initial = 0});
  final List<String> ids;
  final int initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        PageView(
          controller: PageController(initialPage: initial),
          children: [for (final id in ids) InteractiveViewer(child: Center(child: SocialImage(id: id, fit: BoxFit.contain)))],
        ),
        SafeArea(
          child: Semantics(
            button: true,
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.close_rounded, color: Colors.white)),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Poll extends ConsumerWidget {
  const _Poll({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actor = ref.watch(socialActorProvider);
    final r = ref.watch(socialDataProvider.select((d) => d.poll(post, actor)));
    final total = r.counts.fold(0, (a, b) => a + b);
    final closed = post.pollCloses != null && DateTime.now().isAfter(post.pollCloses!);
    final showResults = r.mine.isNotEmpty || closed || post.author == actor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < post.pollOptions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Semantics(
              button: !closed,
              selected: r.mine.contains(i),
              label: showResults ? l10n.socPollOptionResult(post.pollOptions[i], total == 0 ? 0 : (r.counts[i] * 100 / total).round()) : post.pollOptions[i],
              excludeSemantics: true,
              child: InkWell(
                borderRadius: prismCorners(context, 12),
                onTap: closed || actor == null ? null : () => ref.read(socialActionsProvider).vote(actor: actor, post: post, option: i),
                child: ClipRRect(
                  borderRadius: prismCorners(context, 12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: r.mine.contains(i) ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                            borderRadius: prismCorners(context, 12),
                          ),
                        ),
                      ),
                      if (showResults && total > 0)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: r.counts[i] / total,
                            child: ColoredBox(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            if (r.mine.contains(i)) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary)),
                            Expanded(child: Text(post.pollOptions[i])),
                            if (showResults) Text('${total == 0 ? 0 : (r.counts[i] * 100 / total).round()}%', style: theme.textTheme.labelLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Text(
          [l10n.socVoters(r.voters), if (post.pollMulti) l10n.socPollMulti, if (closed) l10n.socPollClosed].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Answers extends ConsumerWidget {
  const _Answers({required this.post, required this.callbacks});
  final Post post;
  final PostCallbacks callbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = ref.watch(socialDataProvider);
    final answers = [for (final s in d.sharesOf[post.id] ?? const <Post>[]) if (s.quoteOf == post.id && s.isLive(d.now)) s];
    if (answers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(l10n.socAnswersCount(answers.length), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.icon, required this.label, required this.onTap, this.hint, this.destructive = false});

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: prismCorners(context, 12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
                    if (hint != null) Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> askText(BuildContext context, {required String title, required String label, String initial = '', int maxLines = 4}) async {
  final c = TextEditingController(text: initial);
  final l10n = context.l10n;
  final ok = await PrismDialog.show<bool>(
    context: context,
    title: title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrismTextField(controller: c, autofocus: true, labelText: label, minLines: 1, maxLines: maxLines),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PrismButton(label: l10n.cancel, onPressed: () => Navigator.of(context).pop(false)),
            const SizedBox(width: 8),
            PrismButton(label: l10n.save, tone: PrismButtonTone.filled, onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      ],
    ),
  );
  final v = c.text.trim();
  return ok == true && v.isNotEmpty ? v : null;
}

Future<void> showPostMenu(BuildContext context, WidgetRef ref, Post post, PostCallbacks cb) {
  final l10n = context.l10n;
  final actor = ref.read(socialActorProvider);
  final d = ref.read(socialDataProvider);
  final mine = actor != null && post.author == actor;
  final a = ref.read(socialActionsProvider);
  final author = post.author;
  return PrismSheet.show<void>(
    context: context,
    builder: (sheet) {
      void run(Future<void> Function() f) {
        Navigator.of(sheet).pop();
        f();
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mine && post.reblogOf == null) MenuRow(icon: Icons.edit_rounded, label: l10n.socEdit, onTap: () => run(() async => cb.compose(edit: post))),
            if (mine)
              MenuRow(
                icon: post.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                label: post.pinned ? l10n.socUnpin : l10n.socPin,
                onTap: () => run(() => a.togglePin(post)),
              ),
            if (mine)
              MenuRow(
                icon: Icons.delete_outline_rounded,
                label: l10n.delete,
                destructive: true,
                onTap: () => run(() async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: l10n.socDeleteTitle,
                    message: l10n.socDeleteMessage,
                    confirmLabel: l10n.delete,
                    cancelLabel: l10n.cancel,
                    destructive: true,
                  );
                  if (ok) await a.deletePost(post.id);
                }),
              ),
            if (author != null) MenuRow(icon: Icons.account_circle_outlined, label: l10n.socViewBlog(alterName(d, author, context)), onTap: () => run(() async => cb.openAlter(author))),
            if (!mine && actor != null) ...[
              MenuRow(
                icon: Icons.visibility_off_outlined,
                label: d.hidden[actor]?.containsKey(post.id) ?? false ? l10n.socUnhide : l10n.socHide,
                onTap: () => run(() => a.toggleHide(actor: actor, postId: post.id)),
              ),
              if (author != null)
                MenuRow(
                  icon: Icons.volume_off_outlined,
                  label: d.isMuted(actor, author) ? l10n.socUnmute(alterName(d, author, context)) : l10n.socMute(alterName(d, author, context)),
                  onTap: () => run(() => a.toggleBlock(actor: actor, target: author, mode: 'mute')),
                ),
              if (author != null)
                MenuRow(
                  icon: Icons.block_rounded,
                  label: d.blocked[actor]?.containsKey(author) ?? false ? l10n.socUnblock(alterName(d, author, context)) : l10n.socBlock(alterName(d, author, context)),
                  destructive: true,
                  onTap: () => run(() async {
                    if (!(d.blocked[actor]?.containsKey(author) ?? false) &&
                        !await confirmIfAsked(context, ref, title: l10n.socBlock(alterName(d, author, context)), message: l10n.socBlockHelp)) {
                      return;
                    }
                    await a.toggleBlock(actor: actor, target: author);
                  }),
                ),
              MenuRow(
                icon: Icons.flag_outlined,
                label: l10n.socReport,
                hint: l10n.socReportHelp,
                destructive: true,
                onTap: () => run(() async {
                  final reason = await askText(context, title: l10n.socReport, label: l10n.socReportReason);
                  if (reason == null) return;
                  await a.report(actor: actor, targetId: post.id, reason: reason);
                  if (context.mounted) PrismToast.success(context, message: l10n.socReported);
                }),
              ),
            ],
          ],
        ),
      );
    },
  );
}
