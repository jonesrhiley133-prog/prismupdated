import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart'
    show timeAgo;
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Notification types with their settings labels.
const socialNotificationTypes = [
  'request',
  'accepted',
  'message',
  'alterMessage',
  'like',
  'comment',
  'reply',
  'reblog',
  'mention',
  'milestoneLike',
];

String notificationTypeText(BuildContext c, String t) => switch (t) {
  'request' => tr(c, 'Friend requests', 'Solicitudes de amistad'),
  'accepted' => tr(c, 'Accepted requests', 'Solicitudes aceptadas'),
  'message' => tr(c, 'Messages', 'Mensajes'),
  'alterMessage' => tr(c, 'Alter messages', 'Mensajes de alters'),
  'like' => tr(c, 'Likes', 'Me gusta'),
  'comment' => tr(c, 'Comments', 'Comentarios'),
  'reply' => tr(c, 'Replies', 'Respuestas'),
  'reblog' => tr(c, 'Reblogs', 'Rebloqueos'),
  'mention' => tr(c, 'Mentions', 'Menciones'),
  'milestoneLike' => tr(c, 'Milestone reactions', 'Reacciones a logros'),
  _ => t,
};

/// Sentence for one notification.
String notificationSentence(BuildContext c, SocialNotification n, String who) =>
    switch (n.type) {
      'request' => tr(
        c,
        '$who sent you a friend request',
        '$who te envió una solicitud de amistad',
      ),
      'accepted' => tr(
        c,
        '$who accepted your friend request',
        '$who aceptó tu solicitud',
      ),
      'message' => tr(c, '$who sent you a message', '$who te envió un mensaje'),
      'alterMessage' => tr(c, '$who sent a message', '$who envió un mensaje'),
      'like' => tr(c, '$who liked your post', 'A $who le gustó tu publicación'),
      'milestoneLike' => tr(
        c,
        '$who reacted to your milestone',
        '$who reaccionó a tu logro',
      ),
      'comment' => tr(
        c,
        '$who commented on your post',
        '$who comentó tu publicación',
      ),
      'reply' => tr(
        c,
        '$who replied to your comment',
        '$who respondió a tu comentario',
      ),
      'reblog' => tr(
        c,
        '$who reblogged your post',
        '$who rebloqueó tu publicación',
      ),
      'mention' => tr(c, '$who mentioned you', '$who te mencionó'),
      _ => who,
    };

IconData _icon(String t) => switch (t) {
  'request' || 'accepted' => PhosphorIcons.userPlus(),
  'message' || 'alterMessage' => PhosphorIcons.chatCircleText(),
  'like' || 'milestoneLike' => PhosphorIcons.heart(),
  'comment' || 'reply' => PhosphorIcons.chatTeardropText(),
  'reblog' => PhosphorIcons.repeat(),
  'mention' => PhosphorIcons.at(),
  _ => PhosphorIcons.bell(),
};

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key, required this.me});
  final SocialActor me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(notificationsProvider(me.profileId));
    final b = ref.read(socialBackendProvider);
    final now = DateTime.now();
    String group(DateTime t) {
      final d = DateUtils.dateOnly(
        now,
      ).difference(DateUtils.dateOnly(t)).inDays;
      if (d <= 0) return tr(context, 'Today', 'Hoy');
      if (d == 1) return tr(context, 'Yesterday', 'Ayer');
      if (d < 7) return tr(context, 'This week', 'Esta semana');
      return tr(context, 'Earlier', 'Antes');
    }

    final rows = <Widget>[];
    String? last;
    for (final n in list) {
      final g = group(n.at);
      if (g != last) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            child: Text(
              g,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        last = g;
      }
      final who = n.actor == null ? null : identityNames(ref, n.actor!);
      final whoText = who == null
          ? '—'
          : (who.isAlter ? '${who.primary} (${who.secondary})' : who.primary);
      final forAlter = n.r.str('alter');
      final alterName = forAlter == null
          ? null
          : ref
                .watch(socialAltersProvider)
                .where((a) => a.id == forAlter)
                .map((a) => alterDisplayName(ref, a))
                .firstOrNull;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: PrismSurface(
            semanticLabel:
                '${notificationSentence(context, n, whoText)}${n.read ? '' : '. Unread'}',
            borderColor: n.read
                ? null
                : theme.colorScheme.primary.withValues(alpha: 0.5),
            onTap: () async {
              await b.markNotifications(me.profileId, id: n.id);
              if (!context.mounted) return;
              final t = n.target;
              switch (n.type) {
                case 'request':
                  context.go('${AppRoutePaths.prismSocial}?s=requests');
                case 'accepted':
                  if (n.actor != null)
                    await context.push(profileRoute(n.actor!.profileId));
                case 'message' || 'alterMessage':
                  if (t != null) await context.push(chatRoute(t));
                default:
                  if (t != null) await context.push(postRoute(t));
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    n.actor == null
                        ? const SizedBox(width: 40, height: 40)
                        : SocialAvatar(
                            actor: n.actor!,
                            size: 40,
                            showAlterBadge: false,
                          ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: prismRound(context),
                          color: theme.colorScheme.primary,
                        ),
                        child: Icon(
                          _icon(n.type),
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notificationSentence(context, n, whoText),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: n.read ? null : FontWeight.w700,
                        ),
                      ),
                      if (alterName != null)
                        Text(
                          tr(context, 'to $alterName', 'para $alterName'),
                          style: theme.textTheme.labelSmall,
                        ),
                      if ((n.preview ?? '').isNotEmpty)
                        Text(
                          n.preview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        timeAgo(context, n.at),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                PrismPopupMenu<String>(
                  icon: AppIcons.moreVert,
                  tooltip: tr(context, 'Notification options', 'Opciones'),
                  items: [
                    PrismMenuItem(
                      value: 'toggle',
                      label: n.read
                          ? tr(
                              context,
                              'Mark as unread',
                              'Marcar como no leído',
                            )
                          : tr(context, 'Mark as read', 'Marcar como leído'),
                      icon: PhosphorIcons.envelopeSimple(),
                    ),
                    PrismMenuItem(
                      value: 'delete',
                      label: tr(context, 'Delete', 'Eliminar'),
                      icon: PhosphorIcons.trash(),
                      destructive: true,
                    ),
                  ],
                  onSelected: (v) => v == 'delete'
                      ? b.deleteNotification(me.profileId, n.id)
                      : b.markNotifications(
                          me.profileId,
                          id: n.id,
                          read: !n.read,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
      children: [
        ClampedBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: tr(context, 'Mark all read', 'Marcar todo leído'),
                      icon: PhosphorIcons.checks(),
                      density: PrismControlDensity.compact,
                      enabled: list.any((n) => !n.read),
                      onPressed: () => b.markNotifications(me.profileId),
                    ),
                    PrismButton(
                      label: tr(context, 'Clear read', 'Borrar leídos'),
                      icon: PhosphorIcons.trash(),
                      density: PrismControlDensity.compact,
                      enabled: list.any((n) => n.read),
                      onPressed: () async {
                        for (final n in list.where((n) => n.read)) {
                          await b.deleteNotification(me.profileId, n.id);
                        }
                      },
                    ),
                  ],
                ),
              if (list.isEmpty)
                EmptyState(
                  icon: Icon(PhosphorIcons.bell()),
                  title: tr(context, 'You’re all caught up', 'Estás al día'),
                  subtitle: tr(
                    context,
                    'Requests, messages, likes, comments and mentions show up here.',
                    'Aquí aparecen solicitudes, mensajes, me gusta, comentarios y menciones.',
                  ),
                ),
              ...rows,
            ],
          ),
        ),
      ],
    );
  }
}
