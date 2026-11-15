import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/social/widgets/social_widgets.dart' show SocialImage;
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

/// Runs a backend call and shows a friendly message if it's refused.
Future<bool> runSocial(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) PrismToast.show(context, message: success, icon: PhosphorIcons.check());
    return true;
  } catch (e) {
    if (context.mounted) {
      final t = socialDeniedText(e);
      PrismToast.show(context, message: tr(context, t.$1, t.$2), icon: PhosphorIcons.warning());
    }
    return false;
  }
}

String profileRoute(String id) => '${AppRoutePaths.prismSocial}/profile/$id';
String alterRoute(String id) => '${AppRoutePaths.prismSocial}/alter/$id';
String chatRoute(String id) => '${AppRoutePaths.prismSocial}/chat/$id';
String postRoute(String id) => '${AppRoutePaths.prismSocial}/post/$id';

/// Names for an identity: alters always show with their system so no one is
/// mistaken for another alter or the whole system.
class IdentityNames {
  const IdentityNames(this.primary, this.secondary, this.isAlter);
  final String primary;
  final String? secondary;
  final bool isAlter;
}

IdentityNames identityNames(WidgetRef ref, SocialActor a) {
  final p = ref.watch(socialProfileByIdProvider(a.profileId));
  final sys = p?.systemName.isNotEmpty == true ? p!.systemName : (p == null ? '—' : '@${p.username}');
  if (a.alterId == null) return IdentityNames(sys, p == null ? null : '@${p.username}', false);
  final alt = ref.watch(socialAltersProvider).where((x) => x.id == a.alterId).firstOrNull;
  final name = alt == null ? '—' : alterDisplayName(ref, alt);
  return IdentityNames(name, sys, true);
}

String alterDisplayName(WidgetRef ref, SocialAlter alt) {
  if (alt.name.trim().isNotEmpty) return alt.name;
  final m = _member(ref, alt.memberId);
  return m?.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider)) ?? '—';
}

Member? _member(WidgetRef ref, String? id) {
  if (id == null) return null;
  return (ref.watch(allMemberListProvider).value ?? const <Member>[]).where((m) => m.id == id).firstOrNull;
}

/// Avatar for a system or an alter.
class SocialAvatar extends ConsumerWidget {
  const SocialAvatar({super.key, required this.actor, this.size = 40, this.showAlterBadge = true});
  final SocialActor actor;
  final double size;
  final bool showAlterBadge;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = ref.watch(socialProfileByIdProvider(actor.profileId));
    Widget circle(Widget child) => ClipOval(child: SizedBox(width: size, height: size, child: child));
    Widget initials(String n) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
      child: Text(n.isEmpty ? '?' : n.characters.first.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimaryContainer, fontSize: size * 0.4)),
    );
    Widget main;
    if (actor.alterId != null) {
      final alt = ref.watch(socialAltersProvider).where((x) => x.id == actor.alterId).firstOrNull;
      final m = _member(ref, alt?.memberId);
      if (alt?.avatar != null) {
        main = circle(SocialImage(id: alt!.avatar!));
      } else if (m != null) {
        main = MemberAvatar(avatarImageData: m.avatarImageData, memberName: m.effectiveName(preferDisplayName: ref.watch(memberNamePreferDisplayProvider)), emoji: m.emoji, customColorEnabled: m.customColorEnabled, customColorHex: m.customColorHex, size: size);
      } else {
        main = initials(alt?.name ?? '?');
      }
      if (!showAlterBadge) return main;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          main,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 2)),
              child: SocialAvatar(actor: SocialActor(actor.profileId), size: size * 0.42, showAlterBadge: false),
            ),
          ),
        ],
      );
    }
    if (p?.avatar != null) return circle(SocialImage(id: p!.avatar!));
    return initials(p?.systemName ?? '?');
  }
}

/// A banner image shown as it is — only a subtle black dim for legibility,
/// never a fade into the card's or theme's colour.
class SocialBanner extends StatelessWidget {
  const SocialBanner({super.key, required this.mediaId, this.height = 140, this.alignY = 0, this.dim = 0.25, this.radius = 0, this.fallback});
  final String? mediaId;
  final double height;
  final double alignY;
  final double dim;
  final double radius;
  final Color? fallback;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: mediaId == null
            ? ColoredBox(color: fallback ?? theme.colorScheme.primaryContainer)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Align(alignment: Alignment(0, alignY), child: SocialImage(id: mediaId!, height: height, width: double.infinity)),
                  if (dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
                ],
              ),
      ),
    );
  }
}

/// Online / idle / do not disturb / offline dot.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.presence, this.size = 12});
  final String presence;
  final double size;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (presence) {
      'online' => const Color(0xFF4CAF7A),
      'idle' => const Color(0xFFE0A93B),
      'dnd' => const Color(0xFFD95B5B),
      _ => theme.colorScheme.outline,
    };
    return Semantics(
      label: presenceText(context, presence),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: presence == 'offline' ? theme.colorScheme.surface : color, shape: BoxShape.circle, border: Border.all(color: presence == 'offline' ? color : theme.colorScheme.surface, width: 2)),
        child: presence == 'dnd' ? Center(child: Container(width: size * 0.5, height: 2, color: theme.colorScheme.surface)) : null,
      ),
    );
  }
}

String presenceText(BuildContext c, String p) => switch (p) {
  'online' => tr(c, 'Online', 'En línea'),
  'idle' => tr(c, 'Idle', 'Ausente'),
  'dnd' => tr(c, 'Do not disturb', 'No molestar'),
  'invisible' => tr(c, 'Invisible', 'Invisible'),
  _ => tr(c, 'Offline', 'Desconectado'),
};

String audienceText(BuildContext c, Audience a) => switch (a) {
  Audience.everyone => tr(c, 'Everyone', 'Todos'),
  Audience.friendsOfFriends => tr(c, 'Friends of friends', 'Amigos de amigos'),
  Audience.friends => tr(c, 'Friends', 'Amigos'),
  Audience.nobody => tr(c, 'Only me', 'Solo yo'),
};

/// Identity line: "Alex · from Moon System" or "Moon System · @moon".
class IdentityLabel extends ConsumerWidget {
  const IdentityLabel({super.key, required this.actor, this.style, this.compact = false});
  final SocialActor actor;
  final TextStyle? style;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = identityNames(ref, actor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(n.primary, maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            if (n.isAlter) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                child: Text(tr(context, 'alter', 'alter'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
              ),
            ],
          ],
        ),
        if (n.secondary != null && !compact) Text(n.isAlter ? tr(context, 'from ${n.secondary}', 'de ${n.secondary}') : n.secondary!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Lets the user switch which managed system (and alter) they act as.
Future<void> showActingSwitcher(BuildContext context, WidgetRef ref) => PrismSheet.show(
  context: context,
  title: tr(context, 'Post and message as…', 'Publicar y escribir como…'),
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final acting = ref.watch(actingProvider);
      final profiles = ref.watch(myProfilesProvider);
      final alters = ref.watch(socialAltersProvider);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in profiles) ...[
              PrismListRow(
                leading: SocialAvatar(actor: SocialActor(p.id), size: 36),
                title: Text(p.systemName),
                subtitle: Text('@${p.username}'),
                trailing: acting == SocialActor(p.id) ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Theme.of(ctx).colorScheme.primary) : null,
                onTap: () {
                  ref.read(actingStoredProvider.notifier).set(SocialActor(p.id));
                  Navigator.of(ctx).pop();
                },
              ),
              for (final a in alters.where((a) => a.profileId == p.id))
                PrismListRow(
                  padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
                  leading: SocialAvatar(actor: a.actor, size: 30),
                  title: Text(alterDisplayName(ref, a)),
                  subtitle: Text(tr(ctx, 'alter of ${p.systemName}', 'alter de ${p.systemName}')),
                  trailing: acting == a.actor ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Theme.of(ctx).colorScheme.primary) : null,
                  onTap: () {
                    ref.read(actingStoredProvider.notifier).set(a.actor);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
            const SizedBox(height: 8),
            Text(tr(ctx, 'You can manage more than one system here (Social settings › Systems).', 'Puedes gestionar más de un sistema aquí (Ajustes sociales › Sistemas).'), style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
      );
    },
  ),
);

/// Acting-as chip for top bars.
class ActingChip extends ConsumerWidget {
  const ActingChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(actingProvider);
    if (a == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: tr(context, 'Acting as ${identityNames(ref, a).primary}. Change', 'Actuando como ${identityNames(ref, a).primary}. Cambiar'),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showActingSwitcher(context, ref),
        child: Padding(padding: const EdgeInsets.all(4), child: SocialAvatar(actor: a, size: 30)),
      ),
    );
  }
}

void openProfile(BuildContext context, SocialActor a) => context.push(a.alterId == null ? profileRoute(a.profileId) : alterRoute(a.alterId!));
