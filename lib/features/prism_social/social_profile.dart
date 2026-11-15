import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart';
import 'package:prism_plurality/features/prism_social/social_friends.dart';
import 'package:prism_plurality/features/prism_social/social_messages.dart';
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Whether [viewer] passes [aud] for content owned by [owner] (UI check; the
/// backend re-checks every write).
bool audienceAllows(WidgetRef ref, Audience aud, String owner, String viewer) {
  if (owner == viewer) return true;
  if (ref.watch(blockedIdsProvider(viewer)).contains(owner)) return false;
  final friends = ref.watch(friendIdsProvider(owner));
  return switch (aud) {
    Audience.everyone => true,
    Audience.friends => friends.contains(viewer),
    Audience.friendsOfFriends => friends.contains(viewer) || ref.watch(friendIdsProvider(viewer)).intersection(friends).isNotEmpty,
    Audience.nobody => false,
  };
}

// ───────────────────────── Profile themes ─────────────────────────

const profileFonts = ['default', 'display', 'serif', 'mono', 'dyslexic'];
const profileLayouts = ['classic', 'centered', 'compact'];

String profileFontText(BuildContext c, String f) => switch (f) {
  'display' => tr(c, 'Display', 'Display'),
  'serif' => tr(c, 'Serif', 'Serif'),
  'mono' => tr(c, 'Monospace', 'Monoespaciada'),
  'dyslexic' => tr(c, 'Dyslexia-friendly', 'Para dislexia'),
  _ => tr(c, 'App default', 'Predeterminada'),
};

String profileLayoutText(BuildContext c, String l) => switch (l) {
  'centered' => tr(c, 'Centered', 'Centrado'),
  'compact' => tr(c, 'Compact', 'Compacto'),
  _ => tr(c, 'Classic', 'Clásico'),
};

/// The theme a profile is shown in. Custom themes only apply when the owner
/// turned on "Use my custom profile theme".
ThemeData profileThemeData(ThemeData base, Map<String, Object?> t, {required bool enabled}) {
  if (!enabled || t.isEmpty) return base;
  final accent = t['accent'] is int ? Color(t['accent']! as int) : null;
  final bg = t['background'] is int ? Color(t['background']! as int) : null;
  final card = t['card'] is int ? Color(t['card']! as int) : null;
  var scheme = accent == null ? base.colorScheme : ColorScheme.fromSeed(seedColor: accent, brightness: base.brightness);
  if (bg != null) {
    final dark = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
    scheme = scheme.copyWith(surface: bg, onSurface: dark ? Colors.white : const Color(0xFF1B1B1F), onSurfaceVariant: dark ? Colors.white70 : Colors.black54);
  }
  if (card != null) scheme = scheme.copyWith(surfaceContainerLow: card, surfaceContainer: card, surfaceContainerHigh: card, surfaceContainerHighest: Color.lerp(card, scheme.onSurface, 0.08));
  final family = switch (t['font']) {
    'display' => 'Unbounded',
    'serif' => 'serif',
    'mono' => 'monospace',
    'dyslexic' => 'OpenDyslexic',
    _ => null,
  };
  final text = family == null ? base.textTheme : base.textTheme.apply(fontFamily: family);
  return base.copyWith(colorScheme: scheme, scaffoldBackgroundColor: bg ?? base.scaffoldBackgroundColor, textTheme: text.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface));
}

// ───────────────────────── Profile screens ─────────────────────────

class SocialProfileScreen extends ConsumerWidget {
  const SocialProfileScreen({super.key, required this.profileId});
  final String profileId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(socialProfileByIdProvider(profileId));
    final theme = profileThemeData(Theme.of(context), p?.theme ?? const {}, enabled: p?.useCustomTheme ?? false);
    return Theme(
      data: theme,
      child: PrismPageScaffold(
        topBar: PrismTopBar(title: p?.systemName ?? tr(context, 'Profile', 'Perfil'), showBackButton: true),
        bodyPadding: EdgeInsets.zero,
        body: ColoredBox(color: theme.colorScheme.surface, child: SocialProfileView(profileId: profileId)),
      ),
    );
  }
}

class SocialProfileView extends ConsumerWidget {
  const SocialProfileView({super.key, required this.profileId, this.embedded = false});
  final String profileId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(socialProfileByIdProvider(profileId));
    final me = ref.watch(actingProvider);
    if (p == null || me == null) return Center(child: Text(tr(context, 'This profile isn’t available.', 'Este perfil no está disponible.')));
    final body = _ProfileBody(p: p, me: me);
    if (!embedded) return body;
    // Embedded (My profile tab): apply my theme here too.
    final theme = profileThemeData(Theme.of(context), p.theme, enabled: p.useCustomTheme);
    return Theme(data: theme, child: ColoredBox(color: theme.colorScheme.surface, child: body));
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.p, required this.me, this.preview = false});
  final SocialProfile p;
  final SocialActor me;
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = p.id == me.profileId;
    final layout = '${p.theme['layout'] ?? 'classic'}';
    final radius = ((p.theme['radius'] as num?) ?? 18).toDouble();
    final blocked = !mine && ref.watch(blockedIdsProvider(me.profileId)).contains(p.id);
    final canView = mine || audienceAllows(ref, p.whoCanSeeProfile, p.id, me.profileId);
    final friends = ref.watch(friendIdsProvider(p.id));
    final mutual = mine ? 0 : friends.intersection(ref.watch(friendIdsProvider(me.profileId))).length;
    final following = ref.watch(followingProvider(me.profileId)).contains(p.id);
    final followers = (ref.watch(trackerKindProvider(SocKind.follow)).value ?? const <TrackerRecord>[]).where((r) => r.str('who') == p.id).length;
    final allPosts = [for (final x in ref.watch(postsProvider)) if (x.author.profileId == p.id && canSeePost(ref.read, x, me.profileId)) x];
    final pinned = [for (final id in p.pinnedPosts) ?allPosts.where((x) => x.id == id).firstOrNull];
    final recent = [for (final x in allPosts) if (!p.pinnedPosts.contains(x.id)) x];
    final alters = [for (final a in ref.watch(socialAltersProvider)) if (a.profileId == p.id && (mine || audienceAllows(ref, a.visibility, p.id, me.profileId))) a];
    final showAlters = mine || audienceAllows(ref, p.whoCanSeeAlters, p.id, me.profileId);
    final links = p.r.strings('links');
    final presence = presenceOf(p, actingAsIt: mine);
    final centered = layout == 'centered';
    final avatarSize = layout == 'compact' ? 64.0 : 88.0;

    final header = Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: (layout == 'compact' ? 110 : 160) + avatarSize / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SocialBanner(mediaId: p.banner, height: layout == 'compact' ? 110 : 160, alignY: p.bannerY, radius: preview ? radius : 0, fallback: theme.colorScheme.primaryContainer),
              Positioned(
                left: centered ? 0 : 16,
                right: centered ? 0 : null,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 4)),
                    child: Stack(clipBehavior: Clip.none, children: [SocialAvatar(actor: SocialActor(p.id), size: avatarSize), Positioned(right: 2, bottom: 2, child: PresenceDot(presence: presence, size: 16))]),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(p.systemName, textAlign: centered ? TextAlign.center : null, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                ['@${p.username}', ?p.pronouns, if (p.showSystemType && (p.systemType ?? '').isNotEmpty) p.systemType!].join(' · '),
                textAlign: centered ? TextAlign.center : null,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (presence != 'offline') Text(presenceText(context, presence), style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );

    if (blocked || !canView) {
      return ListView(
        padding: EdgeInsets.only(bottom: NavBarInset.of(context) + 32),
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(blocked ? tr(context, 'You can’t view this profile.', 'No puedes ver este perfil.') : tr(context, 'This system keeps its profile private.', 'Este sistema mantiene su perfil privado.'), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (!blocked) FriendButton(me: me, other: p),
              ],
            ),
          ),
        ],
      );
    }

    Widget stat(String n, String l) => Column(children: [Text(n, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text(l, style: theme.textTheme.labelSmall)]);

    return ListView(
      padding: EdgeInsets.only(bottom: preview ? 16 : NavBarInset.of(context) + 32),
      shrinkWrap: preview,
      physics: preview ? const NeverScrollableScrollPhysics() : null,
      children: [
        header,
        ClampedBody(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
              children: [
                if (p.description.isNotEmpty) Text(p.description, textAlign: centered ? TextAlign.center : null, style: theme.textTheme.bodyMedium),
                if (links.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: centered ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in links)
                        PrismChip(
                          selected: false,
                          label: Uri.tryParse(l)?.host.isNotEmpty == true ? Uri.parse(l).host : l,
                          avatar: Icon(PhosphorIcons.link(), size: 14),
                          onTap: preview ? null : () async => launchUrl(Uri.parse(l.startsWith('http') ? l : 'https://$l'), mode: LaunchMode.externalApplication),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    stat('${friends.length}', tr(context, 'friends', 'amigos')),
                    stat('$followers', tr(context, 'followers', 'seguidores')),
                    stat('${allPosts.length}', tr(context, 'posts', 'publicaciones')),
                    if (!mine) stat('$mutual', tr(context, 'mutual', 'en común')),
                  ],
                ),
                const SizedBox(height: 12),
                if (!preview)
                  Wrap(
                    alignment: centered ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: mine
                        ? [
                            PrismButton(label: tr(context, 'Edit profile', 'Editar perfil'), icon: PhosphorIcons.pencilSimple(), tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => showProfileEditor(context, p)),
                            PrismButton(label: tr(context, 'New post', 'Publicar'), icon: PhosphorIcons.plus(), density: PrismControlDensity.compact, onPressed: () => showPostComposer(context, me)),
                            PrismButton(label: tr(context, 'Alter profiles', 'Perfiles de alters'), icon: PhosphorIcons.usersThree(), density: PrismControlDensity.compact, onPressed: () => showAlterEditor(context, p.id)),
                          ]
                        : [
                            FriendButton(me: me, other: p),
                            PrismButton(
                              label: following ? tr(context, 'Following', 'Siguiendo') : tr(context, 'Follow', 'Seguir'),
                              icon: following ? PhosphorIcons.check() : PhosphorIcons.plus(),
                              density: PrismControlDensity.compact,
                              onPressed: () => runSocial(context, () => ref.read(socialBackendProvider).toggleFollow(me, p.id)),
                            ),
                            PrismButton(label: tr(context, 'Message', 'Mensaje'), icon: PhosphorIcons.chatCircleText(), density: PrismControlDensity.compact, onPressed: () => showNewConversation(context, me, toProfile: p.id)),
                            PrismPopupMenu<String>(
                              icon: AppIcons.moreVert,
                              tooltip: tr(context, 'More', 'Más'),
                              items: [
                                PrismMenuItem(value: 'block', label: tr(context, 'Block', 'Bloquear'), icon: PhosphorIcons.prohibit(), destructive: true),
                                PrismMenuItem(value: 'report', label: tr(context, 'Report', 'Denunciar'), icon: PhosphorIcons.flag(), destructive: true),
                              ],
                              onSelected: (v) => friendAction(context, ref, me, p, v),
                            ),
                          ],
                  ),
                if (showAlters && alters.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Align(alignment: centered ? Alignment.center : Alignment.centerLeft, child: Text(tr(context, 'Alters', 'Alters'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final a in alters)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Semantics(
                              button: true,
                              label: tr(context, '${alterDisplayName(ref, a)}, alter of ${p.systemName}', '${alterDisplayName(ref, a)}, alter de ${p.systemName}'),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(radius),
                                onTap: preview ? null : () => context.push(alterRoute(a.id)),
                                child: SizedBox(
                                  width: 72,
                                  child: Column(children: [SocialAvatar(actor: a.actor, size: 56, showAlterBadge: false), const SizedBox(height: 4), Text(alterDisplayName(ref, a), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium)]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!preview) ...[
                  if (pinned.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerLeft, child: Text(tr(context, 'Pinned', 'Fijado'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    for (final x in pinned) Padding(padding: const EdgeInsets.only(bottom: 10), child: PostCard(post: x, me: me)),
                  ],
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: Text(tr(context, 'Posts', 'Publicaciones'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  if (recent.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'No posts you can see.', 'No hay publicaciones visibles.'), textAlign: TextAlign.center)),
                  for (final x in recent.take(30)) Padding(padding: const EdgeInsets.only(bottom: 10), child: PostCard(post: x, me: me)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SocialAlterScreen extends ConsumerWidget {
  const SocialAlterScreen({super.key, required this.alterId});
  final String alterId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final a = ref.watch(socialAltersProvider).where((x) => x.id == alterId).firstOrNull;
    final me = ref.watch(actingProvider);
    final p = a == null ? null : ref.watch(socialProfileByIdProvider(a.profileId));
    if (a == null || p == null || me == null) {
      return PrismPageScaffold(topBar: PrismTopBar(title: tr(context, 'Alter', 'Alter'), showBackButton: true), body: Center(child: Text(tr(context, 'This profile isn’t available.', 'Este perfil no está disponible.'))));
    }
    final mine = p.id == me.profileId;
    final visible = mine || (audienceAllows(ref, p.whoCanSeeAlters, p.id, me.profileId) && audienceAllows(ref, a.visibility, p.id, me.profileId));
    final posts = [for (final x in ref.watch(postsProvider)) if (x.author == a.actor && canSeePost(ref.read, x, me.profileId)) x];
    final themed = profileThemeData(theme, p.theme, enabled: p.useCustomTheme);
    final name = alterDisplayName(ref, a);
    return Theme(
      data: themed,
      child: PrismPageScaffold(
        topBar: PrismTopBar(title: name, subtitle: tr(context, 'alter · from ${p.systemName}', 'alter · de ${p.systemName}'), showBackButton: true),
        bodyPadding: EdgeInsets.zero,
        body: ColoredBox(
          color: themed.colorScheme.surface,
          child: !visible
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'This alter’s profile is private.', 'El perfil de este alter es privado.'), textAlign: TextAlign.center)))
              : ListView(
                  padding: EdgeInsets.only(bottom: NavBarInset.of(context) + 32),
                  children: [
                    SizedBox(
                      height: 184,
                      child: Stack(
                        children: [
                          SocialBanner(mediaId: a.banner ?? p.banner, height: 140),
                          Positioned(left: 16, bottom: 0, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: themed.colorScheme.surface, width: 4)), child: SocialAvatar(actor: a.actor, size: 84))),
                        ],
                      ),
                    ),
                    ClampedBody(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IdentityLabel(actor: a.actor, style: themed.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            if (a.pronouns != null) Text(a.pronouns!, style: themed.textTheme.bodyMedium),
                            if ((a.customStatus ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${a.customStatus}”', style: themed.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
                            if (a.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(a.description)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                PrismButton(label: tr(context, 'System profile', 'Perfil del sistema'), icon: PhosphorIcons.usersFour(), density: PrismControlDensity.compact, onPressed: () => context.push(profileRoute(p.id))),
                                if (mine) PrismButton(label: tr(context, 'Edit', 'Editar'), icon: PhosphorIcons.pencilSimple(), density: PrismControlDensity.compact, onPressed: () => showAlterEditor(context, p.id, editing: a)),
                                if (mine) PrismButton(label: tr(context, 'Post as $name', 'Publicar como $name'), icon: PhosphorIcons.plus(), density: PrismControlDensity.compact, onPressed: () => showPostComposer(context, a.actor)),
                                if (!mine && a.canMessage)
                                  PrismButton(
                                    label: tr(context, 'Message $name', 'Escribir a $name'),
                                    icon: PhosphorIcons.chatCircleText(),
                                    tone: PrismButtonTone.filled,
                                    density: PrismControlDensity.compact,
                                    onPressed: () async {
                                      String? id;
                                      final ok = await runSocial(context, () async => id = await ref.read(socialBackendProvider).openConversation(me, a.actor));
                                      if (ok && context.mounted) await context.push(chatRoute(id!));
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(tr(context, 'Posts', 'Publicaciones'), style: themed.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (posts.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'No posts you can see.', 'No hay publicaciones visibles.'), textAlign: TextAlign.center)),
                            for (final x in posts.take(30)) Padding(padding: const EdgeInsets.only(bottom: 10), child: PostCard(post: x, me: me)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ───────────────────────── Profile editor ─────────────────────────

Future<void> showProfileEditor(BuildContext context, SocialProfile p) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _ProfileEditor(p: p, scroll: scroll));

class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({required this.p, required this.scroll});
  final SocialProfile p;
  final ScrollController scroll;
  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final _name = TextEditingController(text: widget.p.systemName);
  late final _user = TextEditingController(text: widget.p.username);
  late final _desc = TextEditingController(text: widget.p.description);
  late final _pronouns = TextEditingController(text: widget.p.pronouns ?? '');
  late final _type = TextEditingController(text: widget.p.systemType ?? '');
  late final _links = TextEditingController(text: widget.p.r.strings('links').join('\n'));
  late bool _showType = widget.p.showSystemType;
  late String? _avatar = widget.p.avatar;
  late String? _banner = widget.p.banner;
  late double _bannerY = widget.p.bannerY;
  late String _status = widget.p.status;
  late bool _useTheme = widget.p.useCustomTheme;
  late Map<String, Object?> _theme = {...widget.p.theme};
  bool _busy = false;

  Map<String, Object?> get _fields => {
    'pronouns': _pronouns.text.trim().isEmpty ? null : _pronouns.text.trim(),
    'systemType': _type.text.trim().isEmpty ? null : _type.text.trim(),
    'showSystemType': _showType,
    'avatar': _avatar,
    'banner': _banner,
    'bannerY': _bannerY,
    'status': _status,
    'useTheme': _useTheme,
    'theme': _theme,
    'links': [for (final l in _links.text.split('\n')) if (l.trim().isNotEmpty) l.trim()],
  };

  /// A preview profile built from the unsaved edits.
  SocialProfile get _preview => SocialProfile(widget.p.r.copyWith(title: _name.text.trim().isEmpty ? widget.p.systemName : _name.text.trim(), body: _desc.text.trim()).withFields({..._fields, 'username': _user.text.trim().toLowerCase()}));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(actingProvider) ?? SocialActor(widget.p.id);
    Widget heading(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 18, 0, 8), child: Text(t, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)));
    Widget colorRow(String key, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            if (_theme[key] != null) PrismButton(label: tr(context, 'Default', 'Predeterminado'), density: PrismControlDensity.compact, onPressed: () => setState(() => _theme = {..._theme}..remove(key))),
          ],
        ),
        const SizedBox(height: 6),
        ColorChoiceRow(value: _theme[key] as int?, onChanged: (v) => setState(() => _theme = {..._theme, key: v}), colors: key == 'accent' ? colorChoices : const [0xFF101014, 0xFF1E1B2E, 0xFF14232B, 0xFF2A1F1A, 0xFFF7F3EE, 0xFFEFF4FA, 0xFFF3EEF8, 0xFFFFFFFF, ...colorChoices]),
        const SizedBox(height: 10),
      ],
    );
    final previewTheme = profileThemeData(theme, _theme, enabled: _useTheme);
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text(tr(context, 'Edit profile', 'Editar perfil'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            PrismButton(
              label: context.l10n.save,
              tone: PrismButtonTone.filled,
              isLoading: _busy,
              onPressed: () async {
                setState(() => _busy = true);
                final ok = await runSocial(
                  context,
                  () => ref.read(socialBackendProvider).updateProfile(widget.p.id, {..._fields, 'username': _user.text}, systemName: _name.text.trim().isEmpty ? null : _name.text.trim(), description: _desc.text.trim()),
                  success: tr(context, 'Profile saved', 'Perfil guardado'),
                );
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (ok) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        heading(tr(context, 'Images', 'Imágenes')),
        Row(
          children: [
            SocialAvatar(actor: SocialActor(widget.p.id), size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismButton(
                    label: tr(context, 'Avatar', 'Avatar'),
                    icon: PhosphorIcons.userCircle(),
                    density: PrismControlDensity.compact,
                    onPressed: () async {
                      final id = await PrismMedia.pickImage(ref, owner: widget.p.id);
                      if (id != null) setState(() => _avatar = id);
                    },
                  ),
                  PrismButton(
                    label: tr(context, 'Banner', 'Banner'),
                    icon: PhosphorIcons.image(),
                    density: PrismControlDensity.compact,
                    onPressed: () async {
                      final id = await PrismMedia.pickImage(ref, owner: widget.p.id);
                      if (id != null) setState(() => _banner = id);
                    },
                  ),
                  if (_avatar != null) PrismButton(label: tr(context, 'Remove avatar', 'Quitar avatar'), density: PrismControlDensity.compact, onPressed: () => setState(() => _avatar = null)),
                  if (_banner != null) PrismButton(label: tr(context, 'Remove banner', 'Quitar banner'), density: PrismControlDensity.compact, onPressed: () => setState(() => _banner = null)),
                ],
              ),
            ),
          ],
        ),
        if (_banner != null) ...[
          const SizedBox(height: 10),
          SocialBanner(mediaId: _banner, height: 110, alignY: _bannerY, radius: 12),
          Row(children: [Text(tr(context, 'Banner position', 'Posición del banner')), Expanded(child: Slider(value: _bannerY, min: -1, max: 1, onChanged: (v) => setState(() => _bannerY = v)))]),
          Text(tr(context, 'Banners are shown as they are, with only a light dim for legibility.', 'Los banners se muestran tal cual, solo con un leve oscurecido para leer mejor.'), style: theme.textTheme.bodySmall),
        ],
        heading(tr(context, 'About', 'Acerca de')),
        PrismTextField(controller: _name, labelText: tr(context, 'System name', 'Nombre del sistema'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        PrismTextField(controller: _user, labelText: tr(context, 'Username', 'Usuario'), prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('@'))),
        const SizedBox(height: 10),
        PrismTextField(controller: _desc, labelText: tr(context, 'Description', 'Descripción'), minLines: 2, maxLines: 6, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        PrismTextField(controller: _pronouns, labelText: tr(context, 'Pronouns (optional)', 'Pronombres (opcional)'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        PrismTextField(controller: _type, labelText: tr(context, 'System type (optional)', 'Tipo de sistema (opcional)'), onChanged: (_) => setState(() {})),
        PrismSwitchRow(title: tr(context, 'Show system type on my profile', 'Mostrar el tipo de sistema'), value: _showType, onChanged: (v) => setState(() => _showType = v), padding: const EdgeInsets.symmetric(vertical: 6)),
        PrismTextField(controller: _links, labelText: tr(context, 'Links (one per line)', 'Enlaces (uno por línea)'), minLines: 1, maxLines: 4, onChanged: (_) => setState(() {})),
        heading(tr(context, 'Status', 'Estado')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final s in const ['online', 'idle', 'dnd', 'invisible']) PrismChip(label: presenceText(context, s == 'invisible' ? 'offline' : s) + (s == 'invisible' ? tr(context, ' (invisible)', ' (invisible)') : ''), selected: _status == s, onTap: () => setState(() => _status = s))],
        ),
        heading(tr(context, 'Profile theme', 'Tema del perfil')),
        PrismSwitchRow(
          title: tr(context, 'Use my custom profile theme', 'Usar mi tema de perfil personalizado'),
          subtitle: tr(context, 'Off shows your profile in each viewer’s app theme.', 'Desactivado, tu perfil usa el tema de cada persona.'),
          value: _useTheme,
          onChanged: (v) => setState(() => _useTheme = v),
          padding: const EdgeInsets.symmetric(vertical: 6),
        ),
        if (_useTheme) ...[
          colorRow('accent', tr(context, 'Accent', 'Acento')),
          colorRow('background', tr(context, 'Background', 'Fondo')),
          colorRow('card', tr(context, 'Cards', 'Tarjetas')),
          Text(tr(context, 'Font', 'Fuente'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final f in profileFonts) PrismChip(label: profileFontText(context, f), selected: (_theme['font'] ?? 'default') == f, onTap: () => setState(() => _theme = {..._theme, 'font': f}))]),
          const SizedBox(height: 10),
          Text(tr(context, 'Layout', 'Diseño'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final l in profileLayouts) PrismChip(label: profileLayoutText(context, l), selected: (_theme['layout'] ?? 'classic') == l, onTap: () => setState(() => _theme = {..._theme, 'layout': l}))]),
          const SizedBox(height: 10),
          Row(children: [Text(tr(context, 'Corner roundness', 'Redondeo')), Expanded(child: Slider(value: ((_theme['radius'] as num?) ?? 18).toDouble(), min: 0, max: 32, divisions: 8, onChanged: (v) => setState(() => _theme = {..._theme, 'radius': v})))]),
          PrismButton(label: tr(context, 'Reset theme', 'Restablecer tema'), icon: PhosphorIcons.arrowCounterClockwise(), density: PrismControlDensity.compact, onPressed: () => setState(() => _theme = {})),
        ],
        heading(tr(context, 'Live preview', 'Vista previa')),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(((_theme['radius'] as num?) ?? 18).toDouble()), border: Border.all(color: theme.colorScheme.outlineVariant)),
          child: Theme(data: previewTheme, child: ColoredBox(color: previewTheme.colorScheme.surface, child: _ProfileBody(p: _preview, me: me, preview: true))),
        ),
      ],
    );
  }
}

// ───────────────────────── Alter profiles ─────────────────────────

/// Manage one alter profile (or pick which alter to add).
Future<void> showAlterEditor(BuildContext context, String profileId, {SocialAlter? editing}) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _AlterEditor(profileId: profileId, editing: editing, scroll: scroll));

class _AlterEditor extends ConsumerStatefulWidget {
  const _AlterEditor({required this.profileId, required this.scroll, this.editing});
  final String profileId;
  final SocialAlter? editing;
  final ScrollController scroll;
  @override
  ConsumerState<_AlterEditor> createState() => _AlterEditorState();
}

class _AlterEditorState extends ConsumerState<_AlterEditor> {
  SocialAlter? _editing;
  late final _name = TextEditingController();
  late final _pronouns = TextEditingController();
  late final _desc = TextEditingController();
  late final _status = TextEditingController();
  String? _memberId;
  String? _avatar;
  String? _banner;
  Audience _visibility = Audience.friends;
  bool _canMessage = true;
  bool _canPost = true;
  bool _editingOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) _load(widget.editing);
  }

  void _load(SocialAlter? a) {
    _editing = a;
    _editingOpen = true;
    _name.text = a?.name ?? '';
    _pronouns.text = a?.pronouns ?? '';
    _desc.text = a?.description ?? '';
    _status.text = a?.customStatus ?? '';
    _memberId = a?.memberId;
    _avatar = a?.avatar;
    _banner = a?.banner;
    _visibility = a?.visibility ?? Audience.friends;
    _canMessage = a?.canMessage ?? true;
    _canPost = a?.canPost ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alters = [for (final a in ref.watch(socialAltersProvider)) if (a.profileId == widget.profileId) a];
    final members = ref.watch(allMemberListProvider).value ?? const <Member>[];
    final b = ref.read(socialBackendProvider);
    if (!_editingOpen) {
      final linked = {for (final a in alters) ?a.memberId};
      return ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(tr(context, 'Alter profiles', 'Perfiles de alters'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(tr(context, 'Alters can have their own social profiles, always shown together with your system so nobody is mistaken for someone else.', 'Los alters pueden tener perfil propio, siempre mostrado junto al sistema para que nadie se confunda.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final a in alters)
            PrismListRow(
              padding: const EdgeInsets.symmetric(vertical: 6),
              leading: SocialAvatar(actor: a.actor, size: 36, showAlterBadge: false),
              title: Text(alterDisplayName(ref, a)),
              subtitle: Text(audienceText(context, a.visibility)),
              trailing: Icon(AppIcons.chevronRight),
              onTap: () => setState(() => _load(a)),
            ),
          const SizedBox(height: 12),
          Text(tr(context, 'Add from your members', 'Añadir desde tus miembros'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in members.where((m) => !linked.contains(m.id)).take(40))
                PrismChip(
                  selected: false,
                  label: m.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider)),
                  onTap: () => setState(() {
                    _load(null);
                    _memberId = m.id;
                    _name.text = m.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider));
                    _pronouns.text = m.pronouns ?? '';
                  }),
                ),
              PrismChip(selected: false, label: tr(context, '+ Without a member', '+ Sin miembro'), onTap: () => setState(() => _load(null))),
            ],
          ),
        ],
      );
    }
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text(_editing == null ? tr(context, 'New alter profile', 'Nuevo perfil de alter') : tr(context, 'Edit alter profile', 'Editar perfil de alter'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            PrismButton(
              label: context.l10n.save,
              tone: PrismButtonTone.filled,
              onPressed: () async {
                if (_name.text.trim().isEmpty) {
                  PrismToast.show(context, message: tr(context, 'Add a name.', 'Añade un nombre.'));
                  return;
                }
                final ok = await runSocial(
                  context,
                  () => b.saveAlter(
                    widget.profileId,
                    editing: _editing?.r,
                    memberId: _memberId,
                    name: _name.text.trim(),
                    description: _desc.text.trim(),
                    fields: {
                      'pronouns': _pronouns.text.trim().isEmpty ? null : _pronouns.text.trim(),
                      'customStatus': _status.text.trim().isEmpty ? null : _status.text.trim(),
                      'avatar': _avatar,
                      'banner': _banner,
                      'visibility': _visibility.name,
                      'canMessage': _canMessage,
                      'canPost': _canPost,
                    },
                  ),
                  success: tr(context, 'Alter profile saved', 'Perfil de alter guardado'),
                );
                if (ok && context.mounted) widget.editing != null ? Navigator.of(context).pop() : setState(() => _editingOpen = false);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_editing != null) SocialAvatar(actor: _editing!.actor, size: 52, showAlterBadge: false),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismButton(
                    label: tr(context, 'Avatar', 'Avatar'),
                    icon: PhosphorIcons.userCircle(),
                    density: PrismControlDensity.compact,
                    onPressed: () async {
                      final id = await PrismMedia.pickImage(ref, owner: widget.profileId);
                      if (id != null) setState(() => _avatar = id);
                    },
                  ),
                  PrismButton(
                    label: tr(context, 'Banner', 'Banner'),
                    icon: PhosphorIcons.image(),
                    density: PrismControlDensity.compact,
                    onPressed: () async {
                      final id = await PrismMedia.pickImage(ref, owner: widget.profileId);
                      if (id != null) setState(() => _banner = id);
                    },
                  ),
                  if (_avatar != null) PrismButton(label: tr(context, 'Use member avatar', 'Usar avatar del miembro'), density: PrismControlDensity.compact, onPressed: () => setState(() => _avatar = null)),
                ],
              ),
            ),
          ],
        ),
        if (_banner != null) Padding(padding: const EdgeInsets.only(top: 10), child: SocialBanner(mediaId: _banner, height: 90, radius: 12)),
        const SizedBox(height: 12),
        PrismTextField(controller: _name, labelText: tr(context, 'Name', 'Nombre')),
        const SizedBox(height: 10),
        PrismTextField(controller: _pronouns, labelText: tr(context, 'Pronouns', 'Pronombres')),
        const SizedBox(height: 10),
        PrismTextField(controller: _status, labelText: tr(context, 'Custom status', 'Estado personalizado')),
        const SizedBox(height: 10),
        PrismTextField(controller: _desc, labelText: tr(context, 'About', 'Acerca de'), minLines: 2, maxLines: 6),
        const SizedBox(height: 14),
        Text(tr(context, 'Who can see this alter', 'Quién puede ver a este alter'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final a in Audience.values) PrismChip(label: audienceText(context, a), selected: _visibility == a, onTap: () => setState(() => _visibility = a))]),
        PrismSwitchRow(title: tr(context, 'Can receive messages', 'Puede recibir mensajes'), value: _canMessage, onChanged: (v) => setState(() => _canMessage = v), padding: const EdgeInsets.symmetric(vertical: 6)),
        PrismSwitchRow(title: tr(context, 'Can post', 'Puede publicar'), value: _canPost, onChanged: (v) => setState(() => _canPost = v), padding: const EdgeInsets.symmetric(vertical: 6)),
        if (_editing != null) ...[
          const SizedBox(height: 12),
          PrismButton(
            label: tr(context, 'Delete alter profile', 'Eliminar perfil de alter'),
            tone: PrismButtonTone.destructive,
            icon: PhosphorIcons.trash(),
            onPressed: () async {
              final ok = await PrismDialog.confirm(context: context, title: tr(context, 'Delete this alter profile?', '¿Eliminar este perfil de alter?'), message: tr(context, 'Their posts stay on your system’s profile. The member itself isn’t touched.', 'Sus publicaciones se quedan. El miembro no se modifica.'), destructive: true, confirmLabel: tr(context, 'Delete', 'Eliminar'), cancelLabel: context.l10n.cancel);
              if (ok != true || !context.mounted) return;
              await ref.read(trackerNotifierProvider.notifier).delete(_editing!.id, children: false);
              if (!context.mounted) return;
              widget.editing != null ? Navigator.of(context).pop() : setState(() => _editingOpen = false);
            },
          ),
        ],
        if (widget.editing == null) ...[const SizedBox(height: 8), PrismButton(label: tr(context, 'Back to list', 'Volver a la lista'), onPressed: () => setState(() => _editingOpen = false))],
      ],
    );
  }
}
