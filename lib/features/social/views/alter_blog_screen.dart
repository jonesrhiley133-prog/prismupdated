import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/features/appearance/views/look_controls.dart';
import 'package:prism_plurality/features/members/utils/member_profile_header_resolver.dart';
import 'package:prism_plurality/features/social/models/social.dart';
import 'package:prism_plurality/features/social/services/social_actions.dart';
import 'package:prism_plurality/features/social/services/social_data.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/features/social/views/compose_post_sheet.dart';
import 'package:prism_plurality/features/social/views/social_nav.dart';
import 'package:prism_plurality/features/social/views/story_viewer.dart';
import 'package:prism_plurality/features/social/widgets/post_card.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Banner bytes for an alter's blog: their blog banner, else their member
/// profile banner.
Uint8List? blogBannerBytes(WidgetRef ref, SocialData d, String memberId) {
  final id = d.profile(memberId).banner;
  if (id != null) return ref.watch(socialImageProvider(id));
  final m = d.members[memberId];
  return m == null ? null : resolveMemberProfileHeader(m).activeImageData;
}

/// An alter's blog: profile header, highlights and posts.
class AlterBlogScreen extends ConsumerWidget {
  const AlterBlogScreen({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final viewer = ref.watch(socialActorProvider);
    final m = d.members[memberId];
    if (m == null) {
      return PrismPageScaffold(topBar: PrismTopBar(title: l10n.socBlog, showBackButton: true), body: Center(child: Text(l10n.socUnknownAlter)));
    }
    final profile = d.profile(memberId);
    final isMe = viewer == memberId;
    final blocked = viewer != null && d.isBlocked(viewer, memberId) && !isMe;
    final posts = blocked ? const <Post>[] : d.blog(memberId, viewer);
    final followers = d.followers[memberId]?.length ?? 0;
    final following = d.following[memberId]?.length ?? 0;
    final banner = blogBannerBytes(ref, d, memberId);
    final accent = profile.accent == null ? theme.colorScheme.primary : Color(profile.accent!);
    final active = d.activeStories(viewer)[memberId] ?? const <Story>[];
    final highlights = d.highlightsOf(memberId).where((h) => h.storyIds.any(d.stories.containsKey)).toList();
    final cb = socialCallbacks(context);
    final bg = profile.background == null ? null : Color(profile.background!);

    Widget body = ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner with avatar overlapping it.
                SizedBox(
                  height: 200,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        bottom: 40,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                          child: banner != null
                              ? Image.memory(banner, fit: BoxFit.cover, alignment: Alignment(profile.bannerX, profile.bannerY), gaplessPlayback: true, excludeFromSemantics: true)
                              : DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.4)]))),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 0,
                        child: AlterAvatar(
                          memberId: memberId,
                          size: 84,
                          ring: active.isEmpty ? null : active.any((s) => !d.hasSeen(s.id, viewer)),
                          onTap: active.isEmpty ? null : () => openStories(context, [memberId]),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(m.name, style: _titleStyle(theme, profile).copyWith(color: accent)),
                      if (m.pronouns?.isNotEmpty ?? false) Text(m.pronouns!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      if (profile.bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: RichPostText(text: profile.bio, onTag: (t) => openTag(context, t))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        children: [
                          _Stat(label: l10n.socPostsN(posts.length), onTap: null),
                          _Stat(label: l10n.socFollowersN(followers), onTap: () => _people(context, ref, l10n.socFollowersTitle, d.followers[memberId]?.toList() ?? const [])),
                          _Stat(label: l10n.socFollowingN(following), onTap: () => _people(context, ref, l10n.socFollowingTitle, d.following[memberId]?.keys.toList() ?? const [])),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isMe) ...[
                            PrismButton(label: l10n.socCustomizeBlog, icon: Icons.brush_outlined, onPressed: () => showBlogEditor(context, memberId)),
                            PrismButton(label: l10n.socNewPost, tone: PrismButtonTone.filled, icon: Icons.edit_rounded, onPressed: () => showComposePost(context)),
                            PrismButton(label: l10n.stoAddStory, icon: Icons.add_circle_outline_rounded, onPressed: () => openStoryComposer(context, memberId)),
                          ] else if (viewer != null) ...[
                            PrismButton(
                              label: d.follows(viewer, memberId) ? l10n.socUnfollow : l10n.socFollow,
                              tone: d.follows(viewer, memberId) ? PrismButtonTone.outlined : PrismButtonTone.filled,
                              enabled: !blocked,
                              onPressed: () => ref.read(socialActionsProvider).toggleFollow(actor: viewer, target: memberId),
                            ),
                            PrismButton(
                              label: d.isMuted(viewer, memberId) ? l10n.socUnmuteShort : l10n.socMuteShort,
                              onPressed: () => ref.read(socialActionsProvider).toggleBlock(actor: viewer, target: memberId, mode: 'mute'),
                            ),
                            PrismButton(
                              label: d.blocked[viewer]?.containsKey(memberId) ?? false ? l10n.socUnblockShort : l10n.socBlockShort,
                              tone: PrismButtonTone.destructive,
                              onPressed: () async {
                                final isBlocked = d.blocked[viewer]?.containsKey(memberId) ?? false;
                                if (!isBlocked) {
                                  final ok = await PrismDialog.confirm(
                                    context: context,
                                    title: l10n.socBlock(m.name),
                                    message: l10n.socBlockHelp,
                                    confirmLabel: l10n.socBlockShort,
                                    cancelLabel: l10n.cancel,
                                    destructive: true,
                                  );
                                  if (!ok) return;
                                }
                                await ref.read(socialActionsProvider).toggleBlock(actor: viewer, target: memberId);
                              },
                            ),
                          ],
                        ],
                      ),
                      if (viewer != null && !isMe && d.follows(memberId, viewer))
                        Padding(padding: const EdgeInsets.only(top: 6), child: Text(l10n.socFollowsYou, style: theme.textTheme.labelMedium?.copyWith(color: accent))),
                      if (highlights.isNotEmpty || isMe) ...[
                        const SizedBox(height: 14),
                        HighlightsRow(memberId: memberId, highlights: highlights, editable: isMe),
                      ],
                      const SizedBox(height: 14),
                      if (blocked)
                        Padding(padding: const EdgeInsets.all(24), child: Text(l10n.socBlockedBlog, textAlign: TextAlign.center))
                      else if (posts.isEmpty)
                        Padding(padding: const EdgeInsets.all(24), child: Text(l10n.socNoPostsYet, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium))
                      else
                        for (final p in posts) PostCard(post: p, callbacks: cb, compact: profile.layout == 'compact'),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.socBlogOf(m.name), showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      backgroundColor: bg,
      bodyPadding: EdgeInsets.zero,
      body: body,
    );
  }

  static TextStyle _titleStyle(ThemeData theme, BlogProfile p) {
    final base = theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 24);
    return switch (p.titleFont) {
      'serif' => base.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w600),
      'mono' => base.copyWith(fontFamily: 'monospace'),
      'bold' => base.copyWith(fontWeight: FontWeight.w900),
      _ => base.copyWith(fontWeight: FontWeight.w700),
    };
  }

  Future<void> _people(BuildContext context, WidgetRef ref, String title, List<String> ids) => PrismSheet.show<void>(
    context: context,
    title: title,
    builder: (sheet) {
      final d = ref.read(socialDataProvider);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ids.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.socNobodyYet)),
            for (final id in ids)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(sheet).pop();
                  openAlterBlog(context, id);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [AlterAvatar(memberId: id, size: 36), const SizedBox(width: 10), Text(alterName(d, id, context))]),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
    ),
  );
}

/// Story highlight circles, grouped by category.
class HighlightsRow extends ConsumerWidget {
  const HighlightsRow({super.key, required this.memberId, required this.highlights, required this.editable});
  final String memberId;
  final List<Highlight> highlights;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final categories = <String, List<Highlight>>{};
    for (final h in highlights) {
      (categories[h.category] ??= []).add(h);
    }
    final keys = categories.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.stoHighlights, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final k in keys.isEmpty ? [''] : keys) ...[
          if (k.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(k, style: theme.textTheme.labelMedium)),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final h in categories[k] ?? const <Highlight>[])
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 68,
                      child: Semantics(
                        button: true,
                        label: l10n.stoHighlightLabel(h.title),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => openHighlight(context, h),
                          onLongPress: editable ? () => editHighlight(context, ref, h) : null,
                          child: Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.outlineVariant, width: 2)),
                                child: ClipOval(child: _HighlightCover(h: h, d: d)),
                              ),
                              const SizedBox(height: 4),
                              Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (editable && k == (keys.isEmpty ? '' : keys.last))
                  SizedBox(
                    width: 68,
                    child: Semantics(
                      button: true,
                      label: l10n.stoNewHighlight,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => newHighlight(context, ref, memberId),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.outlineVariant, width: 2)),
                              child: const Icon(Icons.add_rounded),
                            ),
                            const SizedBox(height: 4),
                            Text(l10n.stoNew, style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HighlightCover extends StatelessWidget {
  const _HighlightCover({required this.h, required this.d});
  final Highlight h;
  final SocialData d;

  @override
  Widget build(BuildContext context) {
    if (h.cover != null) return SocialImage(id: h.cover!);
    final first = h.storyIds.map((id) => d.stories[id]).whereType<Story>().firstOrNull;
    final slide = first?.slides.firstOrNull;
    if (slide?.image != null) return SocialImage(id: slide!.image!);
    return ColoredBox(color: Color(slide?.background ?? 0xFF5C6BC0), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white));
  }
}

Future<void> newHighlight(BuildContext context, WidgetRef ref, String memberId) async {
  final l10n = context.l10n;
  final d = ref.read(socialDataProvider);
  final pool = [...d.archive(memberId), ...(d.activeStories(memberId)[memberId] ?? const <Story>[])];
  if (pool.isEmpty) {
    PrismToast.show(context, message: l10n.stoNoStoriesForHighlight);
    return;
  }
  final title = TextEditingController();
  final category = TextEditingController();
  final picked = <String>{};
  final ok = await PrismSheet.showFullScreen<bool>(
    context: context,
    builder: (sheet, scroll) => StatefulBuilder(
      builder: (sheet, setSheet) => SafeArea(
        child: Column(
          children: [
            PrismSheetTopBar(
              title: l10n.stoNewHighlight,
              trailing: PrismButton(label: l10n.save, tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => Navigator.of(sheet).pop(true)),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  PrismTextField(controller: title, labelText: l10n.stoHighlightName),
                  const SizedBox(height: 8),
                  PrismTextField(controller: category, labelText: l10n.stoCategory, helperText: l10n.stoCategoryHelp),
                  const SizedBox(height: 12),
                  Text(l10n.stoPickStories),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in pool)
                        GestureDetector(
                          onTap: () => setSheet(() => picked.contains(s.id) ? picked.remove(s.id) : picked.add(s.id)),
                          child: Semantics(
                            selected: picked.contains(s.id),
                            button: true,
                            label: MaterialLocalizations.of(context).formatMediumDate(s.postedAt),
                            child: Stack(
                              children: [
                                SizedBox(width: 72, height: 120, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: StorySlideView(slide: s.slides.first, mini: true))),
                                if (picked.contains(s.id)) const Positioned(right: 4, top: 4, child: Icon(Icons.check_circle_rounded, color: Colors.white)),
                              ],
                            ),
                          ),
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
  );
  if (ok != true || title.text.trim().isEmpty) return;
  final a = ref.read(socialActionsProvider);
  for (final s in pool.where((s) => picked.contains(s.id))) {
    if (!s.archived) await a.setStoryArchived(s, true);
  }
  await a.createHighlight(owner: memberId, title: title.text, category: category.text, storyIds: picked.toList());
}

Future<void> editHighlight(BuildContext context, WidgetRef ref, Highlight h) {
  final l10n = context.l10n;
  final a = ref.read(socialActionsProvider);
  return PrismSheet.show<void>(
    context: context,
    title: h.title,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuRow(
            icon: Icons.edit_rounded,
            label: l10n.stoRename,
            onTap: () async {
              Navigator.of(sheet).pop();
              final t = await askText(context, title: l10n.stoRename, label: l10n.stoHighlightName, initial: h.title, maxLines: 1);
              if (t != null) await a.updateHighlight(h, title: t);
            },
          ),
          MenuRow(
            icon: Icons.folder_outlined,
            label: l10n.stoSetCategory,
            onTap: () async {
              Navigator.of(sheet).pop();
              final t = await askText(context, title: l10n.stoCategory, label: l10n.stoCategory, initial: h.category, maxLines: 1);
              if (t != null) await a.updateHighlight(h, category: t);
            },
          ),
          MenuRow(
            icon: Icons.image_outlined,
            label: l10n.stoSetCover,
            onTap: () async {
              Navigator.of(sheet).pop();
              final f = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (f == null) return;
              final id = await ref.read(socialMediaStoreProvider).addImage(await f.readAsBytes(), owner: h.owner);
              if (id != null) await a.updateHighlight(h, cover: id);
            },
          ),
          MenuRow(
            icon: Icons.delete_outline_rounded,
            label: l10n.stoDeleteHighlight,
            destructive: true,
            onTap: () async {
              Navigator.of(sheet).pop();
              await a.deleteHighlight(h);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showBlogEditor(BuildContext context, String memberId) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (context, scroll) => _BlogEditor(memberId: memberId, scroll: scroll),
);

class _BlogEditor extends ConsumerStatefulWidget {
  const _BlogEditor({required this.memberId, required this.scroll});
  final String memberId;
  final ScrollController scroll;

  @override
  ConsumerState<_BlogEditor> createState() => _BlogEditorState();
}

class _BlogEditorState extends ConsumerState<_BlogEditor> {
  late BlogProfile _p = ref.read(socialDataProvider).profile(widget.memberId);
  late final _bio = TextEditingController(text: _p.bio);
  late final _reactions = TextEditingController(text: _p.customReactions.join(' '));

  @override
  void dispose() {
    _bio.dispose();
    _reactions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = ref.watch(socialDataProvider);
    final banner = _p.banner != null ? ref.watch(socialImageProvider(_p.banner!)) : (d.members[widget.memberId] == null ? null : resolveMemberProfileHeader(d.members[widget.memberId]!).activeImageData);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(
            title: l10n.socCustomizeBlog,
            trailing: PrismButton(
              label: l10n.save,
              tone: PrismButtonTone.filled,
              density: PrismControlDensity.compact,
              onPressed: () async {
                final reactions = _reactions.text.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).take(12).toList();
                await ref.read(socialActionsProvider).saveProfile(widget.memberId, _p.copyWith(bio: _bio.text.trim(), customReactions: reactions));
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(l10n.socBanner, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                BannerPositioner(
                  bytes: banner,
                  x: _p.bannerX,
                  y: _p.bannerY,
                  height: 140,
                  onChanged: (x, y) => setState(() => _p = _p.copyWith(bannerX: x, bannerY: y)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: l10n.socChooseBanner,
                      onPressed: () async {
                        final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (f == null) return;
                        final id = await ref.read(socialMediaStoreProvider).addImage(await f.readAsBytes(), owner: widget.memberId);
                        if (id != null) setState(() => _p = _p.copyWith(banner: id, bannerX: 0, bannerY: 0));
                      },
                    ),
                    if (_p.banner != null)
                      PrismButton(label: l10n.socUseProfileBanner, tone: PrismButtonTone.outlined, onPressed: () => setState(() => _p = _p.copyWith(clearBanner: true))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l10n.socBannerHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                PrismTextField(controller: _bio, labelText: l10n.socBio, minLines: 2, maxLines: 6),
                ColorChoiceRow(label: l10n.socAccent, value: _p.accent, onChanged: (v) => setState(() => _p = v == null ? _p.copyWith(clearAccent: true) : _p.copyWith(accent: v))),
                ColorChoiceRow(label: l10n.socBlogBackground, value: _p.background, onChanged: (v) => setState(() => _p = v == null ? _p.copyWith(clearBackground: true) : _p.copyWith(background: v))),
                const SizedBox(height: 12),
                Text(l10n.socTitleFont, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final f in const ['default', 'bold', 'serif', 'mono'])
                      PrismChip(
                        label: switch (f) { 'bold' => l10n.socFontBold, 'serif' => l10n.hwFontSerif, 'mono' => l10n.hwFontMono, _ => l10n.apDefault },
                        selected: _p.titleFont == f,
                        onTap: () => setState(() => _p = _p.copyWith(titleFont: f)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l10n.socLayout, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                PrismSegmentedControl<String>(
                  segments: [PrismSegment(value: 'cards', label: l10n.socLayoutCards), PrismSegment(value: 'compact', label: l10n.socLayoutCompact)],
                  selected: _p.layout,
                  onChanged: (v) => setState(() => _p = _p.copyWith(layout: v)),
                ),
                const SizedBox(height: 12),
                PrismTextField(controller: _reactions, labelText: l10n.socCustomReactions, helperText: l10n.socCustomReactionsHelp),
                const SizedBox(height: 12),
                Text(l10n.stoDefaultAudience, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in Audience.values)
                      if (a != Audience.selected)
                        PrismChip(label: audienceLabel(context, a), selected: _p.storyAudience == a, onTap: () => setState(() => _p = _p.copyWith(storyAudience: a))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Drag a banner to choose which part shows (also used on Headmates).
class BannerPositioner extends StatelessWidget {
  const BannerPositioner({super.key, required this.bytes, required this.x, required this.y, required this.onChanged, this.height = 120});

  final Uint8List? bytes;
  final double x;
  final double y;
  final double height;
  final void Function(double x, double y) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (bytes == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: theme.colorScheme.surfaceContainerHighest),
        alignment: Alignment.center,
        child: Text(l10n.socNoBanner, style: theme.textTheme.bodySmall),
      );
    }
    return Semantics(
      label: l10n.socBannerPositionLabel,
      hint: l10n.socBannerPositionHint,
      onIncrease: () => onChanged(x, (y + 0.1).clamp(-1, 1)),
      onDecrease: () => onChanged(x, (y - 0.1).clamp(-1, 1)),
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onPanUpdate: (dd) => onChanged((x - dd.delta.dx / box.maxWidth * 2).clamp(-1, 1), (y - dd.delta.dy / height * 2).clamp(-1, 1)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Image.memory(bytes!, height: height, width: double.infinity, fit: BoxFit.cover, alignment: Alignment(x, y), gaplessPlayback: true),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.open_with_rounded, size: 14, color: Colors.white), const SizedBox(width: 4), Text(l10n.socDragToPosition, style: const TextStyle(color: Colors.white, fontSize: 11))]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

