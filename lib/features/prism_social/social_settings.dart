import 'package:prism_plurality/features/prism_social/social_connect.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_notifications.dart';
import 'package:prism_plurality/features/prism_social/social_profile.dart';
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

class SocialSettingsScreen extends ConsumerWidget {
  const SocialSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final acting = ref.watch(actingProvider);
    final p = acting == null ? null : ref.watch(socialProfileByIdProvider(acting.profileId));
    final b = ref.read(socialBackendProvider);
    if (acting == null || p == null) {
      return PrismPageScaffold(topBar: PrismTopBar(title: tr(context, 'Social settings', 'Ajustes sociales'), showBackButton: true), body: Center(child: Text(tr(context, 'Create a social profile first.', 'Primero crea un perfil social.'))));
    }
    Future<void> setPrivacy(String key, Object value) => runSocial(context, () => b.updateProfile(p.id, {'privacy': {...p.privacy, key: value}}));
    Future<void> setNotify(String key, bool value) => runSocial(context, () => b.updateProfile(p.id, {'notify': {...p.notifyPrefs, key: value}}));
    Widget heading(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 8), child: Text(t, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)));
    Widget audience(String label, String key, Audience value, {bool allowFof = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PrismSelect<Audience>(
        labelText: label,
        value: value,
        items: [for (final a in Audience.values) if (allowFof || a != Audience.friendsOfFriends) PrismSelectItem(value: a, label: audienceText(context, a))],
        onChanged: (v) {
          if (v != null) setPrivacy(key, v.name);
        },
      ),
    );
    final blocked = [for (final r in ref.watch(socRowsProvider(SocKind.block))) if (r.str('by') == p.id) r];
    final circles = ref.watch(circlesProvider(p.id));
    final profiles = ref.watch(myProfilesProvider);

    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Social settings', 'Ajustes sociales'), subtitle: p.systemName, showBackButton: true, actions: const [FeatureDataAction(featureId: 'prismSocial')]),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr(context, 'Settings apply to the system you’re acting as. Switch systems with the avatar at the top.', 'Los ajustes son del sistema con el que actúas. Cambia con el avatar de arriba.'), style: theme.textTheme.bodySmall),
                heading(tr(context, 'Profile', 'Perfil')),
                PrismSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      PrismListRow(leading: Icon(PhosphorIcons.pencilSimple()), title: Text(tr(context, 'Edit profile and theme', 'Editar perfil y tema')), trailing: Icon(AppIcons.chevronRight), onTap: () => showProfileEditor(context, p)),
                      PrismListRow(leading: Icon(PhosphorIcons.usersThree()), title: Text(tr(context, 'Alter profiles', 'Perfiles de alters')), trailing: Icon(AppIcons.chevronRight), onTap: () => showAlterEditor(context, p.id)),
                      PrismSwitchRow(title: tr(context, 'Use my custom profile theme', 'Usar mi tema de perfil personalizado'), value: p.useCustomTheme, onChanged: (v) => runSocial(context, () => b.updateProfile(p.id, {'useTheme': v}))),
                    ],
                  ),
                ),
                heading(tr(context, 'Privacy', 'Privacidad')),
                audience(tr(context, 'Who can send friend requests', 'Quién puede enviarte solicitudes'), 'requests', p.whoCanRequest),
                audience(tr(context, 'Who can message you', 'Quién puede escribirte'), 'messages', p.whoCanMessage),
                audience(tr(context, 'Who can see your profile', 'Quién puede ver tu perfil'), 'profile', p.whoCanSeeProfile),
                audience(tr(context, 'Who can see your alters', 'Quién puede ver tus alters'), 'alters', p.whoCanSeeAlters),
                audience(tr(context, 'Default audience for new posts', 'Audiencia por defecto de publicaciones'), 'posts', p.defaultPostAudience),
                const SizedBox(height: 6),
                PrismSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      PrismSwitchRow(title: tr(context, 'Alters can receive messages', 'Los alters pueden recibir mensajes'), subtitle: tr(context, 'Each alter’s own setting still applies.', 'Se respeta el ajuste de cada alter.'), value: p.altersReceiveMessages, onChanged: (v) => setPrivacy('altersMessages', v)),
                      PrismSwitchRow(title: tr(context, 'Friendship includes my alters', 'La amistad incluye a mis alters'), subtitle: tr(context, 'Friends of the system can reach alters directly. Off: only the whole system can be messaged by non-alter contacts.', 'Los amigos del sistema pueden escribir a los alters. Desactivado: solo al sistema.'), value: p.friendsReachAlters, onChanged: (v) => setPrivacy('friendsReachAlters', v)),
                      PrismSwitchRow(title: tr(context, 'Show when I’m online', 'Mostrar cuando estoy en línea'), value: p.onlineVisible, onChanged: (v) => setPrivacy('online', v)),
                      PrismSwitchRow(title: tr(context, 'Read receipts', 'Confirmaciones de lectura'), subtitle: tr(context, 'Off: others won’t see when you’ve read, and you won’t see theirs.', 'Desactivado: nadie ve cuándo leíste, ni tú las suyas.'), value: p.readReceipts, onChanged: (v) => setPrivacy('readReceipts', v)),
                      PrismSwitchRow(title: tr(context, 'Appear in Discover', 'Aparecer en Descubrir'), value: p.discoverable, onChanged: (v) => setPrivacy('discover', v)),
                      PrismSwitchRow(title: tr(context, 'Share activity with friends', 'Compartir actividad con amigos'), subtitle: tr(context, 'Never shared unless on. Milestones are only shared when you post them.', 'Nunca se comparte salvo que lo actives. Los logros solo se comparten si los publicas.'), value: p.showActivity, onChanged: (v) => setPrivacy('activity', v)),
                    ],
                  ),
                ),
                heading(tr(context, 'Notifications', 'Avisos')),
                PrismSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      PrismSwitchRow(title: tr(context, 'Device notifications', 'Avisos en el dispositivo'), value: p.pushEnabled, onChanged: (v) => setNotify('push', v)),
                      for (final t in socialNotificationTypes) PrismSwitchRow(title: notificationTypeText(context, t), value: p.notifies(t), onChanged: (v) => setNotify(t, v)),
                    ],
                  ),
                ),
                heading(tr(context, 'Circles', 'Círculos')),
                Text(tr(context, 'Private groups of friends you can post to. Members don’t see the circle’s name or who else is in it.', 'Grupos privados de amigos para publicar. Los miembros no ven el nombre ni quién más está.'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final c in circles)
                  PrismListRow(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    leading: Icon(PhosphorIcons.circlesThree()),
                    title: Text(c.title),
                    subtitle: Text(tr(context, '${c.strings('members').length} friends', '${c.strings('members').length} amigos')),
                    trailing: Icon(AppIcons.chevronRight),
                    onTap: () => _editCircle(context, ref, acting, c),
                  ),
                PrismButton(label: tr(context, 'New circle', 'Nuevo círculo'), icon: PhosphorIcons.plus(), density: PrismControlDensity.compact, onPressed: () => _editCircle(context, ref, acting, null)),
                heading(tr(context, 'Blocked', 'Bloqueados')),
                if (blocked.isEmpty) Text(tr(context, 'You haven’t blocked anyone.', 'No has bloqueado a nadie.'), style: theme.textTheme.bodySmall),
                for (final r in blocked)
                  if (ref.watch(socialProfileByIdProvider(r.str('who')!)) case final o?)
                    PrismListRow(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      leading: SocialAvatar(actor: SocialActor(o.id), size: 36),
                      title: Text(o.systemName),
                      subtitle: Text('@${o.username}'),
                      trailing: PrismButton(label: tr(context, 'Unblock', 'Desbloquear'), density: PrismControlDensity.compact, onPressed: () => runSocial(context, () => b.unblock(acting, o.id), success: tr(context, 'Unblocked', 'Desbloqueado'))),
                    ),
                heading(tr(context, 'Systems on this account', 'Sistemas en esta cuenta')),
                Text(tr(context, 'If you manage more than one system, each can have its own social profile. Switch between them any time.', 'Si gestionas más de un sistema, cada uno puede tener su perfil social. Cambia cuando quieras.'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final x in profiles)
                  PrismListRow(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    leading: SocialAvatar(actor: SocialActor(x.id), size: 36),
                    title: Text(x.systemName),
                    subtitle: Text('@${x.username}'),
                    trailing: x.id == p.id ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: theme.colorScheme.primary) : PrismButton(label: tr(context, 'Switch', 'Cambiar'), density: PrismControlDensity.compact, onPressed: () => ref.read(actingStoredProvider.notifier).set(SocialActor(x.id))),
                  ),
                PrismButton(label: tr(context, 'Add another system', 'Añadir otro sistema'), icon: PhosphorIcons.plus(), density: PrismControlDensity.compact, onPressed: () => _addSystem(context, ref)),
                heading(tr(context, 'Connection', 'Conexión')),
                const SocialConnectionCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSystem(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final user = TextEditingController();
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Add a system', 'Añadir un sistema'),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrismTextField(controller: name, labelText: tr(ctx, 'System name', 'Nombre del sistema')),
            const SizedBox(height: 10),
            PrismTextField(controller: user, labelText: tr(ctx, 'Username', 'Usuario'), prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('@'))),
            const SizedBox(height: 14),
            PrismButton(
              label: tr(ctx, 'Create', 'Crear'),
              tone: PrismButtonTone.filled,
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                String? id;
                final ok = await runSocial(ctx, () async => id = await ref.read(socialBackendProvider).createProfile(username: user.text, systemName: name.text));
                if (ok) {
                  await ref.read(actingStoredProvider.notifier).set(SocialActor(id!));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCircle(BuildContext context, WidgetRef ref, SocialActor me, TrackerRecord? editing) async {
    final name = TextEditingController(text: editing?.title ?? '');
    final members = {...?editing?.strings('members')};
    await PrismSheet.show(
      context: context,
      title: editing == null ? tr(context, 'New circle', 'Nuevo círculo') : tr(context, 'Edit circle', 'Editar círculo'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final friends = [for (final id in ref.read(friendIdsProvider(me.profileId))) ?ref.read(socialProfileByIdProvider(id))];
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrismTextField(controller: name, labelText: tr(ctx, 'Circle name', 'Nombre del círculo')),
                const SizedBox(height: 10),
                if (friends.isEmpty) Text(tr(ctx, 'Circles are made of friends — add some first.', 'Los círculos se hacen con amigos; añade alguno primero.')),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in friends)
                      PrismChip(
                        label: f.systemName,
                        selected: members.contains(f.id),
                        onTap: () => setSheet(() => members.contains(f.id) ? members.remove(f.id) : members.add(f.id)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (editing != null)
                      PrismButton(
                        label: tr(ctx, 'Delete', 'Eliminar'),
                        tone: PrismButtonTone.destructive,
                        onPressed: () async {
                          await runSocial(ctx, () => ref.read(socialBackendProvider).deleteCircle(me, editing.id));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                      ),
                    const Spacer(),
                    PrismButton(
                      label: ctx.l10n.save,
                      tone: PrismButtonTone.filled,
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        final ok = await runSocial(ctx, () => ref.read(socialBackendProvider).saveCircle(me, editingId: editing?.id, name: name.text.trim(), members: members.toList()));
                        if (ok && ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
