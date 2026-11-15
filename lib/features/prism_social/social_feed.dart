import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart' show SocialImage;
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String feedModeText(BuildContext c, FeedMode m) => switch (m) {
  FeedMode.following => tr(c, 'Following', 'Siguiendo'),
  FeedMode.friends => tr(c, 'Friends', 'Amigos'),
  FeedMode.recommended => tr(c, 'Recommended', 'Recomendado'),
  FeedMode.recent => tr(c, 'Recent', 'Reciente'),
  FeedMode.popular => tr(c, 'Popular', 'Popular'),
};

String timeAgo(BuildContext c, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr(c, 'now', 'ahora');
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return DateFormat.MMMd(c.dateLocale).format(t);
}

class SocialFeedSection extends ConsumerStatefulWidget {
  const SocialFeedSection({super.key, required this.me});
  final SocialActor me;
  @override
  ConsumerState<SocialFeedSection> createState() => _SocialFeedSectionState();
}

class _SocialFeedSectionState extends ConsumerState<SocialFeedSection> {
  FeedMode _mode = FeedMode.following;
  int _limit = 30;

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(feedProvider((widget.me.profileId, _mode)));
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
      children: [
        ClampedBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismSurface(
                onTap: () => showPostComposer(context, widget.me),
                child: Row(
                  children: [
                    SocialAvatar(actor: widget.me, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tr(context, 'Share something with your friends…', 'Comparte algo con tus amigos…'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                    Icon(PhosphorIcons.pencilSimpleLine()),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [for (final m in FeedMode.values) Padding(padding: const EdgeInsets.only(right: 6), child: PrismChip(label: feedModeText(context, m), selected: _mode == m, onTap: () => setState(() => _mode = m)))],
                ),
              ),
              const SizedBox(height: 8),
              if (posts.isEmpty)
                EmptyState(
                  icon: Icon(PhosphorIcons.newspaper()),
                  title: tr(context, 'Nothing here yet', 'Aún no hay nada'),
                  subtitle: _mode == FeedMode.following || _mode == FeedMode.friends
                      ? tr(context, 'Add friends or follow systems in Discover, or write the first post.', 'Añade amigos o sigue sistemas en Descubrir, o escribe la primera publicación.')
                      : tr(context, 'No posts you can see yet.', 'Aún no hay publicaciones visibles.'),
                  actionLabel: tr(context, 'Write a post', 'Escribir'),
                  onAction: () => showPostComposer(context, widget.me),
                ),
              for (final p in posts.take(_limit)) Padding(padding: const EdgeInsets.only(bottom: 10), child: PostCard(post: p, me: widget.me)),
              if (posts.length > _limit) PrismButton(label: tr(context, 'Show more', 'Ver más'), onPressed: () => setState(() => _limit += 30)),
            ],
          ),
        ),
      ],
    );
  }
}

/// One post (or reblog, which keeps the original author's attribution).
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.me, this.full = false});
  final SocialPost post;
  final SocialActor me;
  final bool full;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backend = ref.read(socialBackendProvider);
    final reacts = ref.watch(reactsProvider(post.id));
    final liked = reacts.any((r) => r.str('type') == 'like' && r.str('by') == me.profileId);
    final saved = reacts.any((r) => r.str('type') == 'bookmark' && r.str('by') == me.profileId);
    final likes = reacts.where((r) => r.str('type') == 'like').length;
    final comments = ref.watch(commentsProvider(post.id)).length;
    final reblogs = ref.watch(reblogCountProvider(post.id));
    final mine = post.author.profileId == me.profileId;
    final origin = post.origin;
    final originAuthor = SocialActor.fromJson(origin?['author']);
    return PrismSurface(
      onTap: full ? null : () => context.push(postRoute(post.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(onTap: () => openProfile(context, post.author), child: SocialAvatar(actor: post.author, size: 40)),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(onTap: () => openProfile(context, post.author), child: IdentityLabel(actor: post.author))),
              Text('${timeAgo(context, post.at)}${post.edited ? ' · ${tr(context, 'edited', 'editado')}' : ''}', style: theme.textTheme.labelSmall),
              PrismPopupMenu<String>(
                icon: AppIcons.moreVert,
                tooltip: tr(context, 'More', 'Más'),
                items: [
                  if (mine && post.type != 'reblog') PrismMenuItem(value: 'edit', label: tr(context, 'Edit', 'Editar'), icon: AppIcons.editOutlined),
                  if (mine) PrismMenuItem(value: 'pin', label: tr(context, 'Pin to profile', 'Fijar en el perfil'), icon: PhosphorIcons.pushPin()),
                  if (mine) PrismMenuItem(value: 'delete', label: tr(context, 'Delete', 'Eliminar'), icon: AppIcons.deleteOutline, destructive: true),
                  if (!mine) PrismMenuItem(value: 'report', label: tr(context, 'Report', 'Denunciar'), icon: PhosphorIcons.flag()),
                ],
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await showPostComposer(context, me, editing: post);
                    case 'pin':
                      await runSocial(context, () => backend.togglePinPost(me, post.id), success: tr(context, 'Profile pins updated', 'Fijados actualizados'));
                    case 'delete':
                      final ok = await PrismDialog.confirm(context: context, title: tr(context, 'Delete this post?', '¿Eliminar esta publicación?'), message: tr(context, 'Its comments and likes are removed too. Reblogs keep their copy of the original.', 'También se quitan sus comentarios y me gusta. Los reblogs conservan su copia.'), destructive: true, confirmLabel: tr(context, 'Delete', 'Eliminar'), cancelLabel: context.l10n.cancel);
                      if (ok == true && context.mounted) await runSocial(context, () => backend.deletePost(me, post.id));
                    case 'report':
                      await reportSheet(context, ref, me, 'post', post.id);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (post.type == 'reblog' && originAuthor != null) ...[
            if (post.body.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(post.body)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.colorScheme.outlineVariant)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(PhosphorIcons.repeat(), size: 14, color: theme.colorScheme.primary), const SizedBox(width: 6), Expanded(child: Text(tr(context, 'Reblogged from', 'Reblog de'), style: theme.textTheme.labelSmall))]),
                  const SizedBox(height: 6),
                  GestureDetector(onTap: () => openProfile(context, originAuthor), child: Row(children: [SocialAvatar(actor: originAuthor, size: 28), const SizedBox(width: 8), Expanded(child: IdentityLabel(actor: originAuthor, compact: true))])),
                  const SizedBox(height: 8),
                  _Content(type: '${origin!['type'] ?? 'text'}', title: '${origin['title'] ?? ''}', body: '${origin['body'] ?? ''}', media: [for (final m in (origin['media'] as List?) ?? const []) '$m'], link: origin['link'] as String?, milestone: (origin['milestone'] as Map?)?.cast<String, Object?>(), full: full),
                ],
              ),
            ),
          ] else
            _Content(type: post.type, title: post.title, body: post.body, media: post.media, link: post.link, quoteSource: post.quoteSource, milestone: post.milestone, full: full),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(post.circleId != null ? PhosphorIcons.usersThree() : (post.audience == Audience.everyone ? PhosphorIcons.globe() : PhosphorIcons.lock()), size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(post.circleId != null ? tr(context, 'Circle', 'Círculo') : audienceText(context, post.audience), style: theme.textTheme.labelSmall),
            ],
          ),
          const Divider(height: 18),
          Wrap(
            spacing: 2,
            children: [
              _Action(icon: liked ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(), label: '$likes', color: liked ? theme.colorScheme.error : null, semantic: tr(context, liked ? 'Unlike' : 'Like', liked ? 'Quitar me gusta' : 'Me gusta'), onTap: () => runSocial(context, () => backend.toggleReact(me, post.id, 'like'))),
              _Action(icon: PhosphorIcons.chatCircle(), label: '$comments', semantic: tr(context, 'Comments', 'Comentarios'), onTap: () => showComments(context, post, me)),
              _Action(icon: PhosphorIcons.repeat(), label: '$reblogs', semantic: tr(context, 'Reblog', 'Reblog'), onTap: () => _reblog(context, ref)),
              _Action(icon: saved ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill) : PhosphorIcons.bookmarkSimple(), label: '', semantic: tr(context, 'Bookmark', 'Guardar'), onTap: () => runSocial(context, () => backend.toggleReact(me, post.id, 'bookmark'))),
              _Action(icon: PhosphorIcons.shareNetwork(), label: '', semantic: tr(context, 'Share', 'Compartir'), onTap: () => SharePlus.instance.share(ShareParams(text: [if (post.title.isNotEmpty) post.title, post.body.isNotEmpty ? post.body : (post.origin?['body'] ?? '')].join('\n\n')))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reblog(BuildContext context, WidgetRef ref) async {
    final note = TextEditingController();
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Reblog', 'Reblog'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(ctx, 'It appears on your profile with credit to the original author. Only public posts can be reblogged.', 'Aparecerá en tu perfil con crédito al autor original. Solo se pueden rebloguear publicaciones públicas.'), style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 10),
            PrismTextField(controller: note, labelText: tr(ctx, 'Add your thoughts (optional)', 'Añade tu comentario (opcional)'), minLines: 2, maxLines: 6),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PrismButton(
                label: tr(ctx, 'Reblog', 'Reblog'),
                icon: PhosphorIcons.repeat(),
                tone: PrismButtonTone.filled,
                onPressed: () async {
                  final ok = await runSocial(ctx, () async => ref.read(socialBackendProvider).reblog(me, post.id, note: note.text), success: tr(ctx, 'Reblogged', 'Reblogueado'));
                  if (ok && ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, required this.semantic, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String semantic;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$semantic ${label.isEmpty ? '' : label}',
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 19, color: color), if (label.isNotEmpty) ...[const SizedBox(width: 5), Text(label)]]),
      ),
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content({required this.type, required this.title, required this.body, required this.media, this.link, this.quoteSource, this.milestone, this.full = false});
  final String type, title, body;
  final List<String> media;
  final String? link, quoteSource;
  final Map<String, Object?>? milestone;
  final bool full;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (type == 'milestone' && milestone != null) MilestoneCard(data: milestone!),
        if (type == 'question') Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(PhosphorIcons.question(), size: 16, color: theme.colorScheme.primary), const SizedBox(width: 6), Text(tr(context, 'Question', 'Pregunta'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary))])),
        if (type == 'update') Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(tr(context, 'Personal update', 'Novedad personal'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary))),
        if (title.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4, top: 4), child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        if (type == 'quote' && body.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“$body”', style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
                if ((quoteSource ?? '').isNotEmpty) Text('— $quoteSource', style: theme.textTheme.bodySmall),
              ],
            ),
          )
        else if (body.isNotEmpty)
          Text(body, maxLines: full ? null : 10, overflow: full ? null : TextOverflow.fade, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
        if ((link ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Icon(PhosphorIcons.link(), size: 16), const SizedBox(width: 8), Expanded(child: Text(link!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.primary)))]),
            ),
          ),
        if (media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: media.length == 1
                ? ClipRRect(borderRadius: BorderRadius.circular(14), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 360), child: SocialImage(id: media.first, width: double.infinity)))
                : GridView.count(
                    crossAxisCount: media.length == 2 ? 2 : 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [for (final m in media.take(9)) ClipRRect(borderRadius: BorderRadius.circular(10), child: SocialImage(id: m))],
                  ),
          ),
      ],
    );
  }
}

/// A shared Prism milestone (only the details the system chose to include).
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.data});
  final Map<String, Object?> data;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [for (final d in (data['details'] as List?) ?? const []) if (d is Map) ('${d['label']}', '${d['value']}')];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(PhosphorIcons.trophy(), color: theme.colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text('${data['title'] ?? ''}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
          if ('${data['source'] ?? ''}'.isNotEmpty) Text('${data['source']}', style: theme.textTheme.labelSmall),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 6, children: [for (final (l, v) in details) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)), Text(l, style: theme.textTheme.labelSmall)])]),
          ],
        ],
      ),
    );
  }
}

const postTypes = ['text', 'image', 'link', 'quote', 'update', 'question'];

String postTypeText(BuildContext c, String t) => switch (t) {
  'text' => tr(c, 'Text', 'Texto'),
  'image' => tr(c, 'Images', 'Imágenes'),
  'link' => tr(c, 'Link', 'Enlace'),
  'quote' => tr(c, 'Quote', 'Cita'),
  'update' => tr(c, 'Update', 'Novedad'),
  'question' => tr(c, 'Question', 'Pregunta'),
  'milestone' => tr(c, 'Milestone', 'Hito'),
  _ => t,
};

/// Composer for new posts (also edits and milestone shares).
Future<void> showPostComposer(BuildContext context, SocialActor me, {SocialPost? editing, Map<String, Object?>? milestone, String? caption}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) => _Composer(me: me, editing: editing, milestone: milestone, caption: caption, scroll: scroll),
);

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.me, this.editing, this.milestone, this.caption, required this.scroll});
  final SocialActor me;
  final SocialPost? editing;
  final Map<String, Object?>? milestone;
  final String? caption;
  final ScrollController scroll;
  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  late String _type = widget.editing?.type ?? (widget.milestone != null ? 'milestone' : 'text');
  late final _title = TextEditingController(text: widget.editing?.title ?? '');
  late final _body = TextEditingController(text: widget.editing?.body ?? widget.caption ?? '');
  late final _link = TextEditingController(text: widget.editing?.link ?? '');
  late final _source = TextEditingController(text: widget.editing?.quoteSource ?? '');
  late List<String> _media = [...?widget.editing?.media];
  late SocialActor _as = widget.editing?.author ?? widget.me;
  Audience? _audience;
  String? _circle;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(socialProfileByIdProvider(widget.me.profileId));
    final alters = ref.watch(socialAltersProvider).where((a) => a.profileId == widget.me.profileId && a.canPost).toList();
    final circles = ref.watch(circlesProvider(widget.me.profileId));
    final audience = _audience ?? widget.editing?.audience ?? profile?.defaultPostAudience ?? Audience.friends;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(widget.editing != null ? tr(context, 'Edit post', 'Editar publicación') : (widget.milestone != null ? tr(context, 'Share to Social', 'Compartir en Social') : tr(context, 'New post', 'Nueva publicación')), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Close', 'Cerrar'), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.editing == null) ...[
                TrackerLabel(tr(context, 'Post as', 'Publicar como')),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PrismChip(avatar: SocialAvatar(actor: SocialActor(widget.me.profileId), size: 20), label: profile?.systemName ?? '', selected: _as.alterId == null, onTap: () => setState(() => _as = SocialActor(widget.me.profileId))),
                    for (final a in alters) PrismChip(avatar: SocialAvatar(actor: a.actor, size: 20, showAlterBadge: false), label: alterDisplayName(ref, a), selected: _as == a.actor, onTap: () => setState(() => _as = a.actor)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (widget.milestone == null && widget.editing == null) ...[
                Wrap(spacing: 6, runSpacing: 6, children: [for (final t in postTypes) PrismChip(label: postTypeText(context, t), selected: _type == t, onTap: () => setState(() => _type = t))]),
                const SizedBox(height: 12),
              ],
              if (widget.milestone != null) MilestoneCard(data: widget.milestone!),
              if (_type != 'quote') PrismTextField(controller: _title, labelText: tr(context, 'Title (optional)', 'Título (opcional)')),
              const SizedBox(height: 10),
              PrismTextField(controller: _body, labelText: _type == 'quote' ? tr(context, 'Quote', 'Cita') : (_type == 'question' ? tr(context, 'Your question', 'Tu pregunta') : tr(context, 'Write something…', 'Escribe algo…')), minLines: 4, maxLines: 14, helperText: tr(context, 'Mention a system with @username.', 'Menciona a un sistema con @usuario.')),
              if (_type == 'quote') ...[const SizedBox(height: 10), PrismTextField(controller: _source, labelText: tr(context, 'Who said it?', '¿Quién lo dijo?'))],
              if (_type == 'link') ...[const SizedBox(height: 10), PrismTextField(controller: _link, labelText: 'https://…', keyboardType: TextInputType.url)],
              if (_type == 'image' || _type == 'text' || _type == 'update' || _type == 'milestone') ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in _media)
                      GestureDetector(onLongPress: () => setState(() => _media.remove(m)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 72, height: 72, child: SocialImage(id: m)))),
                    if (widget.editing == null)
                      PrismButton(
                        label: tr(context, 'Add images', 'Añadir imágenes'),
                        icon: PhosphorIcons.image(),
                        onPressed: () async {
                          final ids = await PrismMedia.pickImages(ref, owner: widget.me.profileId);
                          if (ids.isNotEmpty) setState(() => _media = [..._media, ...ids].take(9).toList());
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TrackerLabel(tr(context, 'Who can see it', 'Quién puede verlo')),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in Audience.values) PrismChip(label: audienceText(context, a), selected: _circle == null && audience == a, onTap: () => setState(() {
                    _audience = a;
                    _circle = null;
                  })),
                  for (final c in circles) PrismChip(label: '◎ ${c.title}', selected: _circle == c.id, onTap: () => setState(() => _circle = c.id)),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text(tr(context, 'Posting as ${identityNames(ref, _as).primary}', 'Publicando como ${identityNames(ref, _as).primary}'), style: theme.textTheme.bodySmall)),
                PrismButton(
                  label: widget.editing != null ? context.l10n.save : tr(context, 'Post', 'Publicar'),
                  tone: PrismButtonTone.filled,
                  isLoading: _busy,
                  onPressed: _busy
                      ? () {}
                      : () async {
                          setState(() => _busy = true);
                          final b = ref.read(socialBackendProvider);
                          final ok = await runSocial(context, () async {
                            if (widget.editing != null) {
                              await b.editPost(widget.editing!.author, widget.editing!.id, title: _title.text, body: _body.text, audience: _audience);
                            } else {
                              await b.createPost(
                                _as,
                                type: _type == 'image' && _media.isEmpty ? 'text' : _type,
                                title: _title.text,
                                body: _body.text,
                                media: _media,
                                link: _type == 'link' ? _link.text.trim() : null,
                                quoteSource: _type == 'quote' ? _source.text.trim() : null,
                                milestone: widget.milestone,
                                audience: _circle == null ? audience : Audience.friends,
                                circleId: _circle,
                              );
                            }
                          });
                          if (!context.mounted) return;
                          setState(() => _busy = false);
                          if (ok) Navigator.of(context).pop();
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showComments(BuildContext context, SocialPost post, SocialActor me) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _Comments(post: post, me: me, scroll: scroll));

class _Comments extends ConsumerStatefulWidget {
  const _Comments({required this.post, required this.me, required this.scroll});
  final SocialPost post;
  final SocialActor me;
  final ScrollController scroll;
  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  final _c = TextEditingController();
  SocialComment? _replyTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(commentsProvider(widget.post.id));
    final top = all.where((c) => c.replyTo == null).toList();
    Widget row(SocialComment c, {bool reply = false}) => Padding(
      padding: EdgeInsets.only(left: reply ? 40 : 0, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SocialAvatar(actor: c.author, size: reply ? 26 : 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Flexible(child: IdentityLabel(actor: c.author, compact: true)), const SizedBox(width: 6), Text(timeAgo(context, c.at), style: theme.textTheme.labelSmall)]),
                Text(c.body),
                Row(
                  children: [
                    if (!reply) InkWell(onTap: () => setState(() => _replyTo = c), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(tr(context, 'Reply', 'Responder'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)))),
                    if (c.author.profileId == widget.me.profileId || widget.post.author.profileId == widget.me.profileId) ...[
                      const SizedBox(width: 12),
                      InkWell(onTap: () => runSocial(context, () => ref.read(socialBackendProvider).deleteComment(widget.me, c.id)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(tr(context, 'Delete', 'Eliminar'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)))),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(children: [Expanded(child: Text(tr(context, 'Comments', 'Comentarios'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Close', 'Cerrar'), onPressed: () => Navigator.of(context).pop())]),
        ),
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.all(16),
            children: [
              if (all.isEmpty) Text(tr(context, 'No comments yet.', 'Aún no hay comentarios.')),
              for (final c in top) ...[row(c), for (final r in all.where((x) => x.replyTo == c.id)) row(r, reply: true)],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(
              children: [
                if (_replyTo != null) Row(children: [Expanded(child: Text(tr(context, 'Replying to ${identityNames(ref, _replyTo!.author).primary}', 'Respondiendo a ${identityNames(ref, _replyTo!.author).primary}'), style: theme.textTheme.labelSmall)), PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Cancel reply', 'Cancelar'), onPressed: () => setState(() => _replyTo = null))]),
                Row(
                  children: [
                    Expanded(child: PrismTextField(controller: _c, hintText: tr(context, 'Add a comment…', 'Añade un comentario…'), maxLines: 4)),
                    PrismTopBarAction(
                      icon: PhosphorIcons.paperPlaneTilt(),
                      tooltip: tr(context, 'Send', 'Enviar'),
                      onPressed: () async {
                        final text = _c.text;
                        final ok = await runSocial(context, () async => ref.read(socialBackendProvider).comment(widget.me, widget.post.id, text, replyTo: _replyTo?.id));
                        if (ok) {
                          _c.clear();
                          setState(() => _replyTo = null);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> reportSheet(BuildContext context, WidgetRef ref, SocialActor me, String type, String id) async {
  final reason = TextEditingController();
  await PrismSheet.show(
    context: context,
    title: tr(context, 'Report', 'Denunciar'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(ctx, 'Reports are saved for moderation. With the local connection they stay in your account; a Prism Social server would send them to moderators.', 'Las denuncias se guardan para moderación. Con la conexión local quedan en tu cuenta; un servidor de Prism Social las enviaría a moderación.'), style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 10),
          PrismTextField(controller: reason, labelText: tr(ctx, 'What’s wrong?', '¿Qué ocurre?'), minLines: 2, maxLines: 6),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: tr(ctx, 'Send report', 'Enviar'),
              tone: PrismButtonTone.filled,
              onPressed: () async {
                final ok = await runSocial(ctx, () => ref.read(socialBackendProvider).report(me, targetType: type, targetId: id, reason: reason.text.trim()), success: tr(ctx, 'Report saved', 'Denuncia guardada'));
                if (ok && ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// One post with its comments.
class SocialPostScreen extends ConsumerWidget {
  const SocialPostScreen({super.key, required this.postId});
  final String postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(actingProvider);
    final post = ref.watch(postsProvider).where((p) => p.id == postId).firstOrNull;
    final visible = post != null && me != null && canSeePost(ref.read, post, me.profileId);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Post', 'Publicación'), showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: !visible
          ? Center(child: Text(tr(context, 'This post isn’t available.', 'Esta publicación no está disponible.')))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
              children: [
                ClampedBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PostCard(post: post, me: me, full: true),
                      const SizedBox(height: 12),
                      PrismButton(label: tr(context, 'Comments', 'Comentarios'), icon: PhosphorIcons.chatCircle(), onPressed: () => showComments(context, post, me)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
