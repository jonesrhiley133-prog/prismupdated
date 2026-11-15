import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart' show timeAgo, reportSheet;
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart' show SocialImage;
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

const _quickReactions = ['❤️', '😂', '😮', '😢', '👍', '✨'];

class MessagesSection extends ConsumerStatefulWidget {
  const MessagesSection({super.key, required this.me});
  final SocialActor me;
  @override
  ConsumerState<MessagesSection> createState() => _MessagesSectionState();
}

class _MessagesSectionState extends ConsumerState<MessagesSection> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = widget.me.profileId;
    final blocked = ref.watch(blockedIdsProvider(me));
    final convs = ref.watch(conversationsProvider(me));
    final rows = <Widget>[];
    for (final c in convs) {
      final other = c.other(me);
      final mine = c.me(me);
      if (other == null || mine == null) continue;
      final names = identityNames(ref, other);
      final msgs = ref.watch(messagesProvider(c.id));
      final q = _q.toLowerCase();
      if (q.isNotEmpty && !names.primary.toLowerCase().contains(q) && !(names.secondary ?? '').toLowerCase().contains(q) && !msgs.any((m) => m.body.toLowerCase().contains(q))) continue;
      final last = msgs.lastOrNull;
      final unread = c.unreadMarks.containsKey(me) || msgs.any((m) => m.sender.profileId != me && !m.readBy.containsKey(me) && !m.deleted);
      final muted = c.mutedBy.contains(me);
      final preview = last == null
          ? tr(context, 'No messages yet', 'Aún no hay mensajes')
          : last.deleted
          ? tr(context, 'Message deleted', 'Mensaje eliminado')
          : '${last.sender.profileId == me ? tr(context, 'You: ', 'Tú: ') : ''}${last.body.isEmpty ? '📎' : last.body}';
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PrismSurface(
            onTap: () => context.push(chatRoute(c.id)),
            semanticLabel: '${names.primary}${names.isAlter ? ', alter from ${names.secondary}' : ''}. $preview${unread ? '. Unread' : ''}',
            child: Row(
              children: [
                SocialAvatar(actor: other, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: IdentityLabel(actor: other, compact: true)),
                          if (muted) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(PhosphorIcons.bellSlash(), size: 14, color: theme.colorScheme.onSurfaceVariant)),
                          if (last != null) Padding(padding: const EdgeInsets.only(left: 6), child: Text(timeAgo(context, last.at), style: theme.textTheme.labelSmall)),
                        ],
                      ),
                      if (names.isAlter || mine.alterId != null)
                        Text(
                          '${names.isAlter ? tr(context, 'from ${names.secondary}', 'de ${names.secondary}') : ''}${names.isAlter && mine.alterId != null ? ' · ' : ''}${mine.alterId != null ? tr(context, 'as ${identityNames(ref, mine).primary}', 'como ${identityNames(ref, mine).primary}') : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: unread ? FontWeight.w700 : null, color: unread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (unread) Container(margin: const EdgeInsets.only(left: 8), width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary)),
                if (blocked.contains(other.profileId)) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(PhosphorIcons.prohibit(), size: 16, color: theme.colorScheme.error)),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 96),
          children: [
            ClampedBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrismTextField(hintText: tr(context, 'Search conversations', 'Buscar conversaciones'), prefixIcon: Icon(AppIcons.search), onChanged: (v) => setState(() => _q = v)),
                  const SizedBox(height: 10),
                  if (convs.isEmpty) EmptyState(icon: Icon(PhosphorIcons.chatsCircle()), title: tr(context, 'No conversations', 'Sin conversaciones'), subtitle: tr(context, 'Start one with a friend — as your system or as an alter.', 'Empieza una con un amigo, como sistema o como alter.')),
                  ...rows,
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: NavBarInset.of(context) + 16,
          child: PrismButton(label: tr(context, 'New message', 'Nuevo mensaje'), icon: PhosphorIcons.pencilSimpleLine(), tone: PrismButtonTone.filled, onPressed: () => showNewConversation(context, widget.me)),
        ),
      ],
    );
  }
}

/// Picks who you speak as and who you're writing to (a system or one of its alters).
Future<void> showNewConversation(BuildContext context, SocialActor me, {String? toProfile}) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _NewConversation(me: me, toProfile: toProfile, scroll: scroll));

class _NewConversation extends ConsumerStatefulWidget {
  const _NewConversation({required this.me, required this.scroll, this.toProfile});
  final SocialActor me;
  final String? toProfile;
  final ScrollController scroll;
  @override
  ConsumerState<_NewConversation> createState() => _NewConversationState();
}

class _NewConversationState extends ConsumerState<_NewConversation> {
  late SocialActor _as = widget.me;
  late String? _toProfile = widget.toProfile;
  String? _toAlter;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = widget.me.profileId;
    final myAlters = [for (final a in ref.watch(socialAltersProvider)) if (a.profileId == me && a.canMessage) a];
    final friends = ref.watch(friendIdsProvider(me));
    final blocked = ref.watch(blockedIdsProvider(me));
    final targets = [for (final p in ref.watch(socialProfilesProvider)) if (p.id != me && !blocked.contains(p.id) && (friends.contains(p.id) || p.whoCanMessage == Audience.everyone)) p]..sort((a, b) => (friends.contains(b.id) ? 1 : 0).compareTo(friends.contains(a.id) ? 1 : 0));
    final target = _toProfile == null ? null : ref.watch(socialProfileByIdProvider(_toProfile!));
    final theirAlters = target == null || !target.altersReceiveMessages || (!target.friendsReachAlters && !friends.contains(target.id))
        ? const <SocialAlter>[]
        : [
            for (final a in ref.watch(socialAltersProvider))
              if (a.profileId == target.id && a.canMessage && (a.visibility == Audience.everyone || (a.visibility != Audience.nobody && friends.contains(target.id)))) a,
          ];
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(tr(context, 'New message', 'Nuevo mensaje'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Text(tr(context, 'Speak as', 'Hablar como'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PrismChip(label: identityNames(ref, SocialActor(me)).primary, selected: _as.alterId == null, avatar: SocialAvatar(actor: SocialActor(me), size: 20), onTap: () => setState(() => _as = SocialActor(me))),
            for (final a in myAlters) PrismChip(label: alterDisplayName(ref, a), selected: _as.alterId == a.id, avatar: SocialAvatar(actor: a.actor, size: 20, showAlterBadge: false), onTap: () => setState(() => _as = a.actor)),
          ],
        ),
        const SizedBox(height: 16),
        Text(tr(context, 'To', 'Para'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (targets.isEmpty) Text(tr(context, 'Add friends first — most systems only accept messages from friends.', 'Añade amigos primero; la mayoría solo acepta mensajes de amigos.'), style: theme.textTheme.bodySmall),
        for (final p in targets)
          PrismListRow(
            padding: const EdgeInsets.symmetric(vertical: 6),
            leading: SocialAvatar(actor: SocialActor(p.id), size: 36),
            title: Text(p.systemName),
            subtitle: Text('@${p.username}${friends.contains(p.id) ? '' : tr(context, ' · not a friend', ' · no es amigo')}'),
            trailing: _toProfile == p.id ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: theme.colorScheme.primary) : null,
            onTap: () => setState(() {
              _toProfile = p.id;
              _toAlter = null;
            }),
          ),
        if (target != null) ...[
          const SizedBox(height: 12),
          Text(tr(context, 'Who at ${target.systemName}?', '¿Quién en ${target.systemName}?'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PrismChip(label: tr(context, 'The whole system', 'Todo el sistema'), selected: _toAlter == null, onTap: () => setState(() => _toAlter = null)),
              for (final a in theirAlters) PrismChip(label: alterDisplayName(ref, a), selected: _toAlter == a.id, avatar: SocialAvatar(actor: a.actor, size: 20, showAlterBadge: false), onTap: () => setState(() => _toAlter = a.id)),
            ],
          ),
          if (theirAlters.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr(context, 'Their alters aren’t open to individual messages.', 'Sus alters no reciben mensajes individuales.'), style: theme.textTheme.bodySmall)),
        ],
        const SizedBox(height: 20),
        PrismButton(
          label: tr(context, 'Open conversation', 'Abrir conversación'),
          tone: PrismButtonTone.filled,
          isLoading: _busy,
          enabled: _toProfile != null,
          onPressed: () async {
            setState(() => _busy = true);
            String? id;
            final ok = await runSocial(context, () async => id = await ref.read(socialBackendProvider).openConversation(_as, SocialActor(_toProfile!, _toAlter)));
            if (!context.mounted) return;
            setState(() => _busy = false);
            if (ok) {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              unawaited(router.push(chatRoute(id!)));
            }
          },
        ),
      ],
    );
  }
}

class SocialConversationScreen extends ConsumerStatefulWidget {
  const SocialConversationScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConsumerState<SocialConversationScreen> createState() => _SocialConversationScreenState();
}

class _SocialConversationScreenState extends ConsumerState<SocialConversationScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  SocialMessage? _replyTo;
  SocialMessage? _editing;
  List<String> _media = [];
  String? _search;
  String? _lastMarked;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  SocialConversation? _conv(String me) => ref.watch(conversationsProvider(me)).where((c) => c.id == widget.conversationId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acting = ref.watch(actingProvider);
    final conv = acting == null ? null : _conv(acting.profileId);
    if (acting == null || conv == null) {
      return PrismPageScaffold(topBar: PrismTopBar(title: tr(context, 'Conversation', 'Conversación'), showBackButton: true), body: Center(child: Text(tr(context, 'This conversation isn’t available to the system you’re acting as.', 'Esta conversación no está disponible para el sistema actual.'), textAlign: TextAlign.center)));
    }
    final me = conv.me(acting.profileId)!;
    final other = conv.other(acting.profileId)!;
    final otherProfile = ref.watch(socialProfileByIdProvider(other.profileId));
    final myProfile = ref.watch(socialProfileByIdProvider(me.profileId));
    final b = ref.read(socialBackendProvider);
    final all = ref.watch(messagesProvider(conv.id));
    // Mark read when new messages arrive while open.
    final newestOther = all.where((m) => m.sender.profileId != me.profileId && !m.readBy.containsKey(me.profileId)).lastOrNull?.id;
    if ((newestOther != null && newestOther != _lastMarked) || conv.unreadMarks.containsKey(me.profileId) && _lastMarked == null) {
      _lastMarked = newestOther ?? 'mark';
      Future.microtask(() => b.markRead(me, conv.id).catchError((_) {}));
    }
    final msgs = _search == null || _search!.isEmpty ? all : [for (final m in all) if (m.body.toLowerCase().contains(_search!.toLowerCase())) m];
    final pinned = [for (final id in conv.pinned) ?all.where((m) => m.id == id && !m.deleted).firstOrNull];
    final lastMineId = all.where((m) => m.sender.profileId == me.profileId && !m.deleted).lastOrNull?.id;
    final receipts = (otherProfile?.readReceipts ?? false) && (myProfile?.readReceipts ?? false);
    final blocked = ref.watch(blockedIdsProvider(me.profileId)).contains(other.profileId);
    final muted = conv.mutedBy.contains(me.profileId);
    final names = identityNames(ref, other);
    final presence = otherProfile == null ? 'offline' : presenceOf(otherProfile, actingAsIt: false);

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: names.primary,
        subtitle: names.isAlter ? tr(context, 'alter · from ${names.secondary}', 'alter · de ${names.secondary}') : (presence == 'offline' ? names.secondary : presenceText(context, presence)),
        showBackButton: true,
        actions: [
          PrismTopBarAction(icon: AppIcons.search, tooltip: tr(context, 'Search', 'Buscar'), onPressed: () => setState(() => _search = _search == null ? '' : null)),
          PrismPopupMenu<String>(
            icon: AppIcons.moreVert,
            tooltip: tr(context, 'More', 'Más'),
            items: [
              PrismMenuItem(value: 'profile', label: tr(context, 'View profile', 'Ver perfil'), icon: PhosphorIcons.userCircle()),
              PrismMenuItem(value: 'mute', label: muted ? tr(context, 'Unmute', 'Reactivar avisos') : tr(context, 'Mute', 'Silenciar'), icon: muted ? PhosphorIcons.bell() : PhosphorIcons.bellSlash()),
              PrismMenuItem(value: 'unread', label: tr(context, 'Mark as unread', 'Marcar como no leído'), icon: PhosphorIcons.envelopeSimple()),
              PrismMenuItem(value: 'report', label: tr(context, 'Report', 'Denunciar'), icon: PhosphorIcons.flag(), destructive: true),
            ],
            onSelected: (v) async {
              switch (v) {
                case 'profile':
                  openProfile(context, other);
                case 'mute':
                  await runSocial(context, () => b.toggleMute(me, conv.id), success: muted ? tr(context, 'Notifications on', 'Avisos activados') : tr(context, 'Muted', 'Silenciado'));
                case 'unread':
                  final ok = await runSocial(context, () => b.markUnread(me, conv.id));
                  if (ok && context.mounted) context.pop();
                case 'report':
                  await reportSheet(context, ref, me, 'conversation', conv.id);
              }
            },
          ),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          if (_search != null) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: PrismTextField(autofocus: true, hintText: tr(context, 'Search messages', 'Buscar mensajes'), prefixIcon: Icon(AppIcons.search), onChanged: (v) => setState(() => _search = v))),
          // Who is talking to whom — never ambiguous for alters.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Text(
              tr(context, 'You’re speaking as ${identityNames(ref, me).primary}${me.alterId != null ? ' (alter of ${identityNames(ref, me).secondary})' : ''}', 'Hablas como ${identityNames(ref, me).primary}${me.alterId != null ? ' (alter de ${identityNames(ref, me).secondary})' : ''}'),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (pinned.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: PrismSurface(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [Icon(PhosphorIcons.pushPin(), size: 16), const SizedBox(width: 8), Expanded(child: Text(pinned.first.body.isEmpty ? '📎' : pinned.first.body, maxLines: 1, overflow: TextOverflow.ellipsis)), if (pinned.length > 1) Text(' +${pinned.length - 1}', style: theme.textTheme.labelSmall)]),
              ),
            ),
          Expanded(
            child: msgs.isEmpty
                ? Center(child: Text(_search?.isNotEmpty == true ? tr(context, 'No messages match.', 'Ningún mensaje coincide.') : tr(context, 'Say hello 👋', 'Saluda 👋')))
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[msgs.length - 1 - i];
                      final prev = msgs.length - 2 - i >= 0 ? msgs[msgs.length - 2 - i] : null;
                      final showDay = prev == null || !DateUtils.isSameDay(prev.at, m.at);
                      final isLastMine = m.id == lastMineId;
                      return Column(
                        children: [
                          if (showDay) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(DateFormat.yMMMEd().format(m.at), style: theme.textTheme.labelSmall)),
                          _Bubble(
                            m: m,
                            me: me,
                            all: all,
                            pinned: conv.pinned.contains(m.id),
                            readText: receipts && isLastMine && m.readBy.keys.any((k) => k != me.profileId) ? tr(context, 'Seen', 'Visto') : null,
                            onAction: (a) => _action(a, m, me, conv),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (blocked)
            Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'You can’t message this system because one of you has blocked the other.', 'No puedes escribir a este sistema porque uno de los dos bloqueó al otro.'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall))
          else
            _composer(context, me, conv),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, SocialActor me, SocialConversation conv) {
    final theme = Theme.of(context);
    final b = ref.read(socialBackendProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_replyTo != null || _editing != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(_editing != null ? PhosphorIcons.pencilSimple() : PhosphorIcons.arrowBendUpLeft(), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_editing != null ? tr(context, 'Editing message', 'Editando mensaje') : tr(context, 'Replying to ${identityNames(ref, _replyTo!.sender).primary}: ${_replyTo!.body}', 'Respondiendo a ${identityNames(ref, _replyTo!.sender).primary}: ${_replyTo!.body}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                    PrismTopBarAction(
                      icon: PhosphorIcons.x(),
                      tooltip: context.l10n.cancel,
                      onPressed: () => setState(() {
                        if (_editing != null) _text.clear();
                        _replyTo = null;
                        _editing = null;
                      }),
                    ),
                  ],
                ),
              ),
            if (_media.isNotEmpty)
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [for (final m in _media) Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(onTap: () => setState(() => _media.remove(m)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 60, height: 60, child: SocialImage(id: m)))))],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_editing == null)
                  PrismTopBarAction(
                    icon: PhosphorIcons.image(),
                    tooltip: tr(context, 'Add image', 'Añadir imagen'),
                    onPressed: () async {
                      final ids = await PrismMedia.pickImages(ref, owner: me.profileId);
                      if (ids.isNotEmpty) setState(() => _media = [..._media, ...ids].take(6).toList());
                    },
                  ),
                Expanded(child: PrismTextField(controller: _text, hintText: tr(context, 'Message', 'Mensaje'), minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences)),
                PrismTopBarAction(
                  icon: PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                  tooltip: tr(context, 'Send', 'Enviar'),
                  tint: theme.colorScheme.primary,
                  onPressed: () async {
                    final text = _text.text;
                    if (_editing != null) {
                      final ok = await runSocial(context, () => b.editMessage(me, _editing!.id, text));
                      if (ok) {
                        _text.clear();
                        setState(() => _editing = null);
                      }
                      return;
                    }
                    if (text.trim().isEmpty && _media.isEmpty) return;
                    final reply = _replyTo?.id;
                    final media = _media;
                    _text.clear();
                    setState(() {
                      _replyTo = null;
                      _media = [];
                    });
                    final ok = await runSocial(context, () => b.sendMessage(me, conv.id, body: text, media: media, replyTo: reply));
                    if (!ok) _text.text = text;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(String a, SocialMessage m, SocialActor me, SocialConversation conv) async {
    final b = ref.read(socialBackendProvider);
    if (a.startsWith('react:')) {
      await runSocial(context, () => b.react(me, m.id, a.substring(6)));
      return;
    }
    switch (a) {
      case 'reply':
        setState(() => _replyTo = m);
      case 'edit':
        setState(() {
          _editing = m;
          _text.text = m.body;
        });
      case 'delete':
        final ok = await PrismDialog.confirm(context: context, title: tr(context, 'Delete message?', '¿Eliminar mensaje?'), message: tr(context, 'It will show as “Message deleted” for everyone.', 'Se mostrará como “Mensaje eliminado” para todos.'), destructive: true, confirmLabel: tr(context, 'Delete', 'Eliminar'), cancelLabel: context.l10n.cancel);
        if (ok == true && mounted) await runSocial(context, () => b.deleteMessage(me, m.id));
      case 'pin':
        await runSocial(context, () => b.togglePin(me, conv.id, m.id));
    }
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.m, required this.me, required this.all, required this.pinned, required this.onAction, this.readText});
  final SocialMessage m;
  final SocialActor me;
  final List<SocialMessage> all;
  final bool pinned;
  final String? readText;
  final ValueChanged<String> onAction;

  Future<void> _showOptions(BuildContext context, List<PrismMenuItem<String>> items) async {
    final picked = await PrismSheet.show<String>(
      context: context,
      title: tr(context, 'Message', 'Mensaje'),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!m.deleted)
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  for (final e in _quickReactions)
                    Semantics(
                      button: true,
                      label: tr(ctx, 'React $e', 'Reaccionar $e'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(ctx).pop('react:$e'),
                        child: Padding(padding: const EdgeInsets.all(10), child: Text(e, style: const TextStyle(fontSize: 26))),
                      ),
                    ),
                ],
              ),
            for (final i in items)
              PrismListRow(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                leading: Icon(i.icon),
                title: Text(i.label),
                destructive: i.destructive,
                onTap: () => Navigator.of(ctx).pop(i.value),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.body));
      if (context.mounted) PrismToast.show(context, message: tr(context, 'Copied', 'Copiado'), icon: PhosphorIcons.check());
      return;
    }
    onAction(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = m.sender.profileId == me.profileId;
    final ownIdentity = m.sender == me;
    final reply = m.replyTo == null ? null : all.where((x) => x.id == m.replyTo).firstOrNull;
    final bg = mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh;
    final fg = mine ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;
    final names = identityNames(ref, m.sender);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16).copyWith(bottomRight: mine ? const Radius.circular(4) : null, bottomLeft: mine ? null : const Radius.circular(4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: fg.withValues(alpha: 0.5), width: 3))),
              child: Text('${identityNames(ref, reply.sender).primary}: ${reply.deleted ? tr(context, 'deleted', 'eliminado') : reply.body}', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8))),
            ),
          if (m.deleted)
            Text(tr(context, 'Message deleted', 'Mensaje eliminado'), style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: fg.withValues(alpha: 0.7)))
          else ...[
            for (final id in m.media) Padding(padding: const EdgeInsets.only(bottom: 4), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 220), child: SocialImage(id: id)))),
            if (m.body.isNotEmpty) Text(m.body, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
          ],
          const SizedBox(height: 2),
          Text(
            [DateFormat.jm().format(m.at), if (m.edited && !m.deleted) tr(context, 'edited', 'editado'), if (pinned) tr(context, 'pinned', 'fijado')].join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
    final items = [
      if (!m.deleted) PrismMenuItem(value: 'reply', label: tr(context, 'Reply', 'Responder'), icon: PhosphorIcons.arrowBendUpLeft()),
      if (!m.deleted && m.body.isNotEmpty) PrismMenuItem(value: 'copy', label: tr(context, 'Copy text', 'Copiar texto'), icon: PhosphorIcons.copy()),
      if (!m.deleted) PrismMenuItem(value: 'pin', label: pinned ? tr(context, 'Unpin', 'Desfijar') : tr(context, 'Pin', 'Fijar'), icon: PhosphorIcons.pushPin()),
      if (ownIdentity && !m.deleted && m.body.isNotEmpty) PrismMenuItem(value: 'edit', label: tr(context, 'Edit', 'Editar'), icon: PhosphorIcons.pencilSimple()),
      if (ownIdentity && !m.deleted) PrismMenuItem(value: 'delete', label: tr(context, 'Delete', 'Eliminar'), icon: PhosphorIcons.trash(), destructive: true),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine || m.sender != me) Padding(padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2), child: Text(names.isAlter ? '${names.primary} · ${names.secondary}' : names.primary, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[SocialAvatar(actor: m.sender, size: 28), const SizedBox(width: 6)],
              Flexible(
                child: Semantics(
                  onLongPressHint: tr(context, 'message options', 'opciones del mensaje'),
                  customSemanticsActions: {
                    if (items.isNotEmpty) CustomSemanticsAction(label: tr(context, 'Message options', 'Opciones del mensaje')): () => _showOptions(context, items),
                  },
                  child: GestureDetector(onLongPress: items.isEmpty ? null : () => _showOptions(context, items), child: bubble),
                ),
              ),
            ],
          ),
          if (m.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2, left: mine ? 0 : 34),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final e in m.reactions.entries)
                    Semantics(
                      button: true,
                      label: '${e.key} ${e.value.length}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onAction('react:${e.key}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: e.value.contains(me.key) ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest),
                          child: Text('${e.key} ${e.value.length}', style: theme.textTheme.labelSmall),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (readText != null) Padding(padding: const EdgeInsets.only(top: 2, right: 4), child: Text(readText!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}
