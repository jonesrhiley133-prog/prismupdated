import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart';
import 'package:prism_plurality/features/prism_social/social_friends.dart';
import 'package:prism_plurality/features/prism_social/social_messages.dart';
import 'package:prism_plurality/features/prism_social/social_notifications.dart';
import 'package:prism_plurality/features/prism_social/social_profile.dart';
import 'package:prism_plurality/features/prism_social/social_widgets.dart';
import 'package:prism_plurality/features/settings/views/feature_data_screen.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum SocialSection { feed, friends, requests, messages, discover, profile, notifications }

/// Prism Social: feed, friends, requests, messages, discover, profile and
/// notifications for systems and their alters.
class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key, this.section});
  final String? section;
  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  late SocialSection _section = SocialSection.values.where((s) => s.name == widget.section).firstOrNull ?? SocialSection.feed;

  @override
  void didUpdateWidget(SocialHubScreen old) {
    super.didUpdateWidget(old);
    final s = SocialSection.values.where((s) => s.name == widget.section).firstOrNull;
    if (s != null && widget.section != old.section) _section = s;
  }

  @override
  Widget build(BuildContext context) {
    final acting = ref.watch(actingProvider);
    if (acting == null) return const _CreateProfileScreen();
    final me = acting.profileId;
    // Keep "last active" fresh while Social is open.
    Future.microtask(() => ref.read(socialBackendProvider).touch(me).catchError((_) {}));
    final reqs = ref.watch(pendingRequestsProvider(me)).incoming.length;
    final msgs = ref.watch(unreadMessagesProvider(me));
    final notes = ref.watch(unreadNotificationCountProvider(me));
    String label(SocialSection s) => switch (s) {
      SocialSection.feed => tr(context, 'Feed', 'Muro'),
      SocialSection.friends => tr(context, 'Friends', 'Amigos'),
      SocialSection.requests => tr(context, 'Requests', 'Solicitudes') + (reqs > 0 ? ' · $reqs' : ''),
      SocialSection.messages => tr(context, 'Messages', 'Mensajes') + (msgs > 0 ? ' · $msgs' : ''),
      SocialSection.discover => tr(context, 'Discover', 'Descubrir'),
      SocialSection.profile => tr(context, 'My profile', 'Mi perfil'),
      SocialSection.notifications => tr(context, 'Notifications', 'Avisos') + (notes > 0 ? ' · $notes' : ''),
    };
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Social', 'Social'),
        actions: [
          const FeatureDataAction(featureId: 'prismSocial'),
          PrismTopBarAction(icon: AppIcons.navSettings, tooltip: tr(context, 'Social settings', 'Ajustes sociales'), onPressed: () => context.push('${AppRoutePaths.prismSocial}/settings')),
          const ActingChip(),
        ],
      ),
      bodyPadding: EdgeInsets.zero,
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [for (final s in SocialSection.values) Padding(padding: const EdgeInsets.only(right: 6), child: PrismChip(label: label(s), selected: _section == s, onTap: () => setState(() => _section = s)))],
            ),
          ),
          Expanded(
            child: switch (_section) {
              SocialSection.feed => SocialFeedSection(me: acting),
              SocialSection.friends => FriendsSection(me: acting),
              SocialSection.requests => RequestsSection(me: acting),
              SocialSection.messages => MessagesSection(me: acting),
              SocialSection.discover => DiscoverSection(me: acting),
              SocialSection.profile => SocialProfileView(profileId: me, embedded: true),
              SocialSection.notifications => NotificationsSection(me: acting),
            },
          ),
        ],
      ),
    );
  }
}

class _CreateProfileScreen extends ConsumerStatefulWidget {
  const _CreateProfileScreen();
  @override
  ConsumerState<_CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<_CreateProfileScreen> {
  final _user = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backend = ref.watch(socialBackendProvider);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Social', 'Social')),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(AppIcons.navSocial, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(tr(context, 'Set up your system’s social profile', 'Configura el perfil social de tu sistema'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'Friends, messages and posts happen between systems — your alters can have their own profiles too. Nothing from the rest of Prism is shared unless you choose to share it.', 'Las amistades, mensajes y publicaciones son entre sistemas, y tus alters pueden tener perfil propio. Nada del resto de Prism se comparte salvo que tú lo elijas.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                PrismTextField(controller: _name, labelText: tr(context, 'System name', 'Nombre del sistema')),
                const SizedBox(height: 10),
                PrismTextField(controller: _user, labelText: tr(context, 'Username', 'Nombre de usuario'), helperText: tr(context, '3–30 letters, numbers, _ or .', '3–30 letras, números, _ o .'), prefixIcon: const Padding(padding: EdgeInsets.all(12), child: Text('@'))),
                const SizedBox(height: 10),
                PrismTextField(controller: _desc, labelText: tr(context, 'Short description (optional)', 'Descripción breve (opcional)'), minLines: 2, maxLines: 5),
                const SizedBox(height: 16),
                PrismButton(
                  label: tr(context, 'Create profile', 'Crear perfil'),
                  tone: PrismButtonTone.filled,
                  isLoading: _busy,
                  onPressed: _busy
                      ? () {}
                      : () async {
                          if (_name.text.trim().isEmpty) {
                            PrismToast.show(context, message: tr(context, 'Add your system’s name.', 'Añade el nombre del sistema.'));
                            return;
                          }
                          setState(() => _busy = true);
                          final ok = await runSocial(context, () async {
                            final id = await backend.createProfile(username: _user.text, systemName: _name.text, description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), primary: true);
                            await ref.read(actingStoredProvider.notifier).set(SocialActor(id));
                          });
                          if (mounted && !ok) setState(() => _busy = false);
                        },
                ),
                const SizedBox(height: 16),
                PrismSurface(
                  child: Text(
                    tr(
                      context,
                      'Connection: ${backend.name}. Social works between the systems managed in this Prism account and syncs across your own devices. Reaching other people’s systems needs a Prism Social server, which isn’t available yet — nothing here pretends otherwise.',
                      'Conexión: este dispositivo (local). Social funciona entre los sistemas gestionados en esta cuenta y se sincroniza entre tus dispositivos. Para llegar a otros sistemas hace falta un servidor de Prism Social, aún no disponible; nada aquí aparenta lo contrario.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
