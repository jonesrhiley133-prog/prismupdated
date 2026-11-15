import 'package:go_router/go_router.dart';

import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart' show timeAgo, reportSheet;
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum _FriendsTab { all, online, recent, favorites }

enum _Sort { name, active, added }

/// Card for a system: banner (no theme fade), avatar, names, presence.
class SystemCard extends ConsumerWidget {
  const SystemCard({super.key, required this.profile, required this.me, this.trailing, this.subtitle, this.onTap, this.favorite = false});
  final SocialProfile profile;
  final SocialActor me;
  final Widget? trailing;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool favorite;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presence = presenceOf(profile, actingAsIt: profile.id == me.profileId);
    return PrismSurface(
      padding: EdgeInsets.zero,
      onTap: onTap ?? () => context.push(profileRoute(profile.id)),
      semanticLabel: '${profile.systemName}, @${profile.username}, ${presenceText(context, presence)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profile.banner != null) SocialBanner(mediaId: profile.banner, height: 70, alignY: profile.bannerY, radius: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(clipBehavior: Clip.none, children: [SocialAvatar(actor: SocialActor(profile.id), size: 44), Positioned(right: -2, bottom: -2, child: PresenceDot(presence: presence))]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Flexible(child: Text(profile.systemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))), if (favorite) ...[const SizedBox(width: 4), Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), size: 14, color: const Color(0xFFE0A93B))]]),
                      Text('@${profile.username}${profile.onlineVisible && profile.lastActive != null && presence == 'offline' ? ' · ${tr(context, 'active ${timeAgo(context, profile.lastActive!)} ago', 'activo hace ${timeAgo(context, profile.lastActive!)}')}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      if ((subtitle ?? profile.description).isNotEmpty) Text(subtitle ?? profile.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FriendsSection extends ConsumerStatefulWidget {
  const FriendsSection({super.key, required this.me});
  final SocialActor me;
  @override
  ConsumerState<FriendsSection> createState() => _FriendsSectionState();
}

class _FriendsSectionState extends ConsumerState<FriendsSection> {
  _FriendsTab _tab = _FriendsTab.all;
  _Sort _sort = _Sort.name;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final me = widget.me.profileId;
    final ids = ref.watch(friendIdsProvider(me));
    final friendships = {
      for (final r in ref.watch(socRowsProvider(SocKind.friendship)))
        if (r.str('a') == me) r.str('b')!: r else if (r.str('b') == me) r.str('a')!: r,
    };
    final profiles = [for (final id in ids) ?ref.watch(socialProfileByIdProvider(id))];
    bool fav(SocialProfile p) => friendships[p.id]?.strings('fav').contains(me) ?? false;
    final list = profiles.where((p) {
      final presence = presenceOf(p, actingAsIt: false);
      final q = _q.toLowerCase();
      final match = q.isEmpty || p.systemName.toLowerCase().contains(q) || p.username.contains(q);
      return match &&
          switch (_tab) {
            _FriendsTab.all => true,
            _FriendsTab.online => presence != 'offline',
            _FriendsTab.recent => p.onlineVisible && p.lastActive != null && DateTime.now().difference(p.lastActive!).inDays < 3,
            _FriendsTab.favorites => fav(p),
          };
    }).toList();
    list.sort(switch (_sort) {
      _Sort.name => (a, b) => a.systemName.toLowerCase().compareTo(b.systemName.toLowerCase()),
      _Sort.active => (a, b) => (b.onlineVisible ? b.lastActive ?? DateTime(0) : DateTime(0)).compareTo(a.onlineVisible ? a.lastActive ?? DateTime(0) : DateTime(0)),
      _Sort.added => (a, b) => (friendships[b.id]?.createdAt ?? DateTime(0)).compareTo(friendships[a.id]?.createdAt ?? DateTime(0)),
    });
    final b = ref.read(socialBackendProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
      children: [
        ClampedBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(hintText: tr(context, 'Search friends', 'Buscar amigos'), prefixIcon: Icon(AppIcons.search), onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (t, l) in [(_FriendsTab.all, tr(context, 'All · ${ids.length}', 'Todos · ${ids.length}')), (_FriendsTab.online, tr(context, 'Online', 'En línea')), (_FriendsTab.recent, tr(context, 'Recently active', 'Activos hace poco')), (_FriendsTab.favorites, tr(context, 'Favorites', 'Favoritos'))])
                    PrismChip(label: l, selected: _tab == t, onTap: () => setState(() => _tab = t)),
                  PrismPopupMenu<_Sort>(
                    icon: PhosphorIcons.sortAscending(),
                    tooltip: tr(context, 'Sort', 'Ordenar'),
                    items: [
                      PrismMenuItem(value: _Sort.name, label: tr(context, 'By name', 'Por nombre'), icon: PhosphorIcons.textAa()),
                      PrismMenuItem(value: _Sort.active, label: tr(context, 'Recently active', 'Actividad reciente'), icon: PhosphorIcons.clock()),
                      PrismMenuItem(value: _Sort.added, label: tr(context, 'Newest friends', 'Amigos más nuevos'), icon: PhosphorIcons.userPlus()),
                    ],
                    onSelected: (v) => setState(() => _sort = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (ids.isEmpty)
                EmptyState(icon: Icon(PhosphorIcons.usersThree()), title: tr(context, 'No friends yet', 'Aún no hay amigos'), subtitle: tr(context, 'Find systems in Discover and send a friend request.', 'Busca sistemas en Descubrir y envía una solicitud.'))
              else if (list.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'No friends match.', 'Ningún amigo coincide.'), textAlign: TextAlign.center)),
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SystemCard(
                    profile: p,
                    me: widget.me,
                    favorite: fav(p),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrismTopBarAction(
                          icon: PhosphorIcons.chatCircleText(),
                          tooltip: tr(context, 'Message', 'Mensaje'),
                          onPressed: () async {
                            String? id;
                            final ok = await runSocial(context, () async => id = await b.openConversation(widget.me, SocialActor(p.id)));
                            if (ok && context.mounted) await context.push(chatRoute(id!));
                          },
                        ),
                        PrismPopupMenu<String>(
                          icon: AppIcons.moreVert,
                          tooltip: tr(context, 'More', 'Más'),
                          items: [
                            PrismMenuItem(value: 'profile', label: tr(context, 'View profile', 'Ver perfil'), icon: PhosphorIcons.userCircle()),
                            PrismMenuItem(value: 'fav', label: fav(p) ? tr(context, 'Remove favorite', 'Quitar de favoritos') : tr(context, 'Favorite', 'Favorito'), icon: PhosphorIcons.star()),
                            PrismMenuItem(value: 'remove', label: tr(context, 'Remove friend', 'Quitar amigo'), icon: PhosphorIcons.userMinus(), destructive: true),
                            PrismMenuItem(value: 'block', label: tr(context, 'Block', 'Bloquear'), icon: PhosphorIcons.prohibit(), destructive: true),
                          ],
                          onSelected: (v) => friendAction(context, ref, widget.me, p, v),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> friendAction(BuildContext context, WidgetRef ref, SocialActor me, SocialProfile p, String action) async {
  final b = ref.read(socialBackendProvider);
  switch (action) {
    case 'profile':
      await context.push(profileRoute(p.id));
    case 'fav':
      await runSocial(context, () => b.toggleFavorite(me, p.id));
    case 'remove':
      final ok = await PrismDialog.confirm(context: context, title: tr(context, 'Remove ${p.systemName}?', '¿Quitar a ${p.systemName}?'), message: tr(context, 'You won’t see their friends-only posts any more. Conversations stay.', 'Dejarás de ver sus publicaciones para amigos. Las conversaciones se quedan.'), destructive: true, confirmLabel: tr(context, 'Remove', 'Quitar'), cancelLabel: context.l10n.cancel);
      if (ok == true && context.mounted) await runSocial(context, () => b.removeFriend(me, p.id), success: tr(context, 'Friend removed', 'Amigo quitado'));
    case 'block':
      final ok = await PrismDialog.confirm(context: context, title: tr(context, 'Block ${p.systemName}?', '¿Bloquear a ${p.systemName}?'), message: tr(context, 'You’ll stop being friends, pending requests are cancelled, and neither of you can message, request or see each other’s posts. You can unblock in Social settings.', 'Dejaréis de ser amigos, se cancelan solicitudes y ninguno podrá escribir, enviar solicitudes ni ver publicaciones del otro. Puedes desbloquear en Ajustes sociales.'), destructive: true, confirmLabel: tr(context, 'Block', 'Bloquear'), cancelLabel: context.l10n.cancel);
      if (ok == true && context.mounted) await runSocial(context, () => b.block(me, p.id), success: tr(context, 'Blocked', 'Bloqueado'));
    case 'report':
      await reportSheet(context, ref, me, 'system', p.id);
  }
}

class RequestsSection extends ConsumerWidget {
  const RequestsSection({super.key, required this.me});
  final SocialActor me;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(pendingRequestsProvider(me.profileId));
    final b = ref.read(socialBackendProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
      children: [
        ClampedBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr(context, 'Incoming · ${r.incoming.length}', 'Recibidas · ${r.incoming.length}'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (r.incoming.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(tr(context, 'No requests right now.', 'No hay solicitudes ahora.'), style: theme.textTheme.bodySmall)),
              for (final q in r.incoming)
                if (ref.watch(socialProfileByIdProvider(q.str('from')!)) case final p?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SystemCard(profile: p, me: me, subtitle: (q.body ?? '').isNotEmpty ? '“${q.body}”' : tr(context, 'Sent ${timeAgo(context, q.occurredAt ?? q.createdAt)} ago', 'Enviada hace ${timeAgo(context, q.occurredAt ?? q.createdAt)}')),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            PrismButton(label: tr(context, 'Accept', 'Aceptar'), icon: PhosphorIcons.check(), tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.acceptRequest(me, q.id), success: tr(context, 'You’re now friends with ${p.systemName}', 'Ahora eres amigo de ${p.systemName}'))),
                            PrismButton(label: tr(context, 'Decline', 'Rechazar'), density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.declineRequest(me, q.id))),
                            PrismButton(label: tr(context, 'Block', 'Bloquear'), density: PrismControlDensity.compact, tone: PrismButtonTone.destructive, onPressed: () => friendAction(context, ref, me, p, 'block')),
                            PrismButton(label: tr(context, 'Report', 'Denunciar'), density: PrismControlDensity.compact, onPressed: () => friendAction(context, ref, me, p, 'report')),
                          ],
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              Text(tr(context, 'Sent · ${r.outgoing.length}', 'Enviadas · ${r.outgoing.length}'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (r.outgoing.isEmpty) Text(tr(context, 'No pending requests.', 'No hay solicitudes pendientes.'), style: theme.textTheme.bodySmall),
              for (final q in r.outgoing)
                if (ref.watch(socialProfileByIdProvider(q.str('to')!)) case final p?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SystemCard(
                      profile: p,
                      me: me,
                      subtitle: tr(context, 'Pending · sent ${timeAgo(context, q.occurredAt ?? q.createdAt)} ago', 'Pendiente · enviada hace ${timeAgo(context, q.occurredAt ?? q.createdAt)}'),
                      trailing: PrismButton(label: tr(context, 'Cancel', 'Cancelar'), density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.cancelRequest(me, q.id))),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Friend status button between [me] and [other].
class FriendButton extends ConsumerWidget {
  const FriendButton({super.key, required this.me, required this.other});
  final SocialActor me;
  final SocialProfile other;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.read(socialBackendProvider);
    if (other.id == me.profileId) return const SizedBox.shrink();
    final friends = ref.watch(friendIdsProvider(me.profileId)).contains(other.id);
    final blocked = ref.watch(blockedIdsProvider(me.profileId)).contains(other.id);
    final req = ref.watch(pendingRequestsProvider(me.profileId));
    final sent = req.outgoing.where((r) => r.str('to') == other.id).firstOrNull;
    final received = req.incoming.where((r) => r.str('from') == other.id).firstOrNull;
    if (blocked) return PrismButton(label: tr(context, 'Blocked', 'Bloqueado'), enabled: false, density: PrismControlDensity.compact, onPressed: () {});
    if (friends) return PrismButton(label: tr(context, 'Friends', 'Amigos'), icon: PhosphorIcons.userCheck(), density: PrismControlDensity.compact, onPressed: () => friendAction(context, ref, me, other, 'remove'));
    if (received != null) return PrismButton(label: tr(context, 'Accept request', 'Aceptar solicitud'), tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.acceptRequest(me, received.id)));
    if (sent != null) return PrismButton(label: tr(context, 'Requested', 'Solicitado'), density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.cancelRequest(me, sent.id), success: tr(context, 'Request cancelled', 'Solicitud cancelada')));
    return PrismButton(label: tr(context, 'Add friend', 'Añadir amigo'), icon: PhosphorIcons.userPlus(), tone: PrismButtonTone.filled, density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.sendRequest(me, other.id), success: tr(context, 'Friend request sent', 'Solicitud enviada')));
  }
}

class DiscoverSection extends ConsumerStatefulWidget {
  const DiscoverSection({super.key, required this.me});
  final SocialActor me;
  @override
  ConsumerState<DiscoverSection> createState() => _DiscoverSectionState();
}

class _DiscoverSectionState extends ConsumerState<DiscoverSection> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = widget.me.profileId;
    final blocked = ref.watch(blockedIdsProvider(me));
    final friends = ref.watch(friendIdsProvider(me));
    // Only systems that opted into discovery; nothing private is shown.
    final all = [for (final p in ref.watch(socialProfilesProvider)) if (p.id != me && p.discoverable && !blocked.contains(p.id)) p];
    final q = _q.trim().toLowerCase().replaceFirst('@', '');
    final results = q.isEmpty ? <SocialProfile>[] : [for (final p in all) if (p.username.contains(q) || p.systemName.toLowerCase().contains(q)) p];
    int mutual(SocialProfile p) => ref.watch(friendIdsProvider(p.id)).intersection(friends).length;
    final mutuals = [for (final p in all) if (!friends.contains(p.id) && mutual(p) > 0) p]..sort((a, b) => mutual(b).compareTo(mutual(a)));
    final recent = [for (final p in all) if (p.onlineVisible && p.lastActive != null) p]..sort((a, b) => b.lastActive!.compareTo(a.lastActive!));
    final newest = [...all]..sort((a, b) => b.r.createdAt.compareTo(a.r.createdAt));
    final recommended = [for (final p in all) if (!friends.contains(p.id)) p]..sort((a, b) => (mutual(b) * 3 + (b.description.isNotEmpty ? 1 : 0)).compareTo(mutual(a) * 3 + (a.description.isNotEmpty ? 1 : 0)));
    Widget section(String title, List<SocialProfile> list) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              for (final p in list.take(6)) Padding(padding: const EdgeInsets.only(bottom: 8), child: SystemCard(profile: p, me: widget.me, subtitle: mutual(p) > 0 ? tr(context, '${mutual(p)} mutual friends', '${mutual(p)} amigos en común') : null, trailing: FriendButton(me: widget.me, other: p))),
            ],
          );
    final backend = ref.watch(socialBackendProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
      children: [
        ClampedBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrismTextField(hintText: tr(context, 'Search by username or system name', 'Busca por usuario o nombre del sistema'), prefixIcon: Icon(AppIcons.search), onChanged: (v) => setState(() => _q = v)),
              if (q.isNotEmpty) ...[
                section(tr(context, 'Results', 'Resultados'), results),
                if (results.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'No systems found.', 'No se encontraron sistemas.'), textAlign: TextAlign.center)),
              ] else ...[
                section(tr(context, 'Recommended', 'Recomendados'), recommended),
                section(tr(context, 'Mutual friends', 'Amigos en común'), mutuals),
                section(tr(context, 'Recently active', 'Activos recientemente'), recent),
                section(tr(context, 'New systems', 'Sistemas nuevos'), newest),
                if (all.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(tr(context, 'No other systems to show yet.', 'Aún no hay otros sistemas.'), textAlign: TextAlign.center)),
              ],
              const SizedBox(height: 16),
              Text(
                backend.reachesOtherDevices
                    ? tr(context, 'Only systems that allow discovery appear here.', 'Solo aparecen sistemas que permiten ser descubiertos.')
                    : tr(context, 'Discover shows the systems managed in this Prism account. Finding systems elsewhere needs a Prism Social server.', 'Descubrir muestra los sistemas gestionados en esta cuenta. Encontrar otros sistemas requiere un servidor de Prism Social.'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
