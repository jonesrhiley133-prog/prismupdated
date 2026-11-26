import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart'
    show timeAgo;
import 'package:prism_plurality/features/prism_social/social_remote.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String serverErrorText(BuildContext c, Object e) {
  if (e is SocialDenied) {
    final t = socialDeniedText(e);
    return tr(c, t.$1, t.$2);
  }
  final m = e is SocialServerError ? e.message : '$e';
  return switch (m) {
    'not_a_prism_server' => tr(
      c,
      'That address isn’t a Prism Social server.',
      'Esa dirección no es un servidor de Prism Social.',
    ),
    'invite_required' => tr(
      c,
      'This server needs an invite code.',
      'Este servidor necesita un código de invitación.',
    ),
    'registration_closed' => tr(
      c,
      'This server isn’t accepting new accounts.',
      'Este servidor no acepta cuentas nuevas.',
    ),
    'rate_limited' => tr(
      c,
      'Too many attempts — try again in a little while.',
      'Demasiados intentos; prueba en un rato.',
    ),
    'too_many_profiles' => tr(
      c,
      'This server limits how many systems one account can have.',
      'Este servidor limita cuántos sistemas puede tener una cuenta.',
    ),
    'timeout' => tr(
      c,
      'The server didn’t answer in time.',
      'El servidor no respondió a tiempo.',
    ),
    'unauthorized' => tr(
      c,
      'The server no longer recognises this device. Disconnect and connect again.',
      'El servidor ya no reconoce este dispositivo. Desconecta y vuelve a conectar.',
    ),
    _ => tr(
      c,
      'Couldn’t reach the server ($m).',
      'No se pudo conectar con el servidor ($m).',
    ),
  };
}

/// Connection card for Social settings.
class SocialConnectionCard extends ConsumerWidget {
  const SocialConnectionCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conn = ref.watch(socialConnectionProvider);
    final status = ref.watch(socialSyncProvider);
    if (conn == null) {
      return PrismSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, 'On this device', 'En este dispositivo'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'Friends, messages and posts work between the systems on this Prism account and sync across your own devices. Connect to a Prism Social server to reach other people’s systems.',
                'Funciona entre los sistemas de esta cuenta y se sincroniza entre tus dispositivos. Conéctate a un servidor de Prism Social para llegar a otros sistemas.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            PrismButton(
              label: tr(
                context,
                'Connect to a server',
                'Conectar a un servidor',
              ),
              icon: PhosphorIcons.globe(),
              tone: PrismButtonTone.filled,
              onPressed: () => showConnectSheet(context),
            ),
          ],
        ),
      );
    }
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                status.error == null
                    ? PhosphorIcons.cloudCheck()
                    : PhosphorIcons.cloudWarning(),
                color: status.error == null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'Connected to ${conn.host}',
                    'Conectado a ${conn.host}',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status.error != null
                ? serverErrorText(context, SocialServerError(status.error!))
                : status.syncing
                ? tr(context, 'Syncing…', 'Sincronizando…')
                : status.lastSync == null
                ? tr(
                    context,
                    'Waiting for first sync…',
                    'Esperando la primera sincronización…',
                  )
                : tr(
                    context,
                    'Up to date · synced ${timeAgo(context, status.lastSync!)} ago',
                    'Al día · sincronizado hace ${timeAgo(context, status.lastSync!)}',
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: status.error != null ? theme.colorScheme.error : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              context,
              'Your Social profiles, friends, messages and posts live on this server. Nothing else from Prism is sent.',
              'Tus perfiles sociales, amigos, mensajes y publicaciones viven en este servidor. No se envía nada más de Prism.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrismButton(
                label: tr(context, 'Sync now', 'Sincronizar'),
                icon: PhosphorIcons.arrowsClockwise(),
                density: PrismControlDensity.compact,
                onPressed: () =>
                    ref.read(socialSyncProvider.notifier).syncNow(),
              ),
              PrismButton(
                label: tr(context, 'Disconnect', 'Desconectar'),
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: tr(
                      context,
                      'Disconnect from ${conn.host}?',
                      '¿Desconectar de ${conn.host}?',
                    ),
                    message: tr(
                      context,
                      'All your devices go back to on-device Social. Your server account stays, so you can reconnect later.',
                      'Todos tus dispositivos vuelven a Social local. Tu cuenta del servidor se conserva para reconectar después.',
                    ),
                    confirmLabel: tr(context, 'Disconnect', 'Desconectar'),
                    cancelLabel: context.l10n.cancel,
                  );
                  if (ok == true && context.mounted)
                    await _run(context, () => disconnectSocialServer(ref.read));
                },
              ),
              PrismButton(
                label: tr(
                  context,
                  'Delete server account',
                  'Eliminar cuenta del servidor',
                ),
                tone: PrismButtonTone.destructive,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final ok = await PrismDialog.confirm(
                    context: context,
                    title: tr(
                      context,
                      'Delete your account on ${conn.host}?',
                      '¿Eliminar tu cuenta en ${conn.host}?',
                    ),
                    message: tr(
                      context,
                      'Your systems, alter profiles, posts, comments, likes, friendships and uploaded images are removed from the server for good. Messages you sent show as deleted.',
                      'Tus sistemas, perfiles de alters, publicaciones, comentarios, me gusta, amistades e imágenes se eliminan del servidor para siempre. Tus mensajes aparecerán como eliminados.',
                    ),
                    destructive: true,
                    confirmLabel: tr(context, 'Delete', 'Eliminar'),
                    cancelLabel: context.l10n.cancel,
                  );
                  if (ok == true && context.mounted)
                    await _run(
                      context,
                      () =>
                          disconnectSocialServer(ref.read, deleteAccount: true),
                      success: tr(
                        context,
                        'Server account deleted',
                        'Cuenta del servidor eliminada',
                      ),
                    );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool> _run(
  BuildContext context,
  Future<void> Function() f, {
  String? success,
}) async {
  try {
    await f();
    if (success != null && context.mounted)
      PrismToast.show(context, message: success, icon: PhosphorIcons.check());
    return true;
  } catch (e) {
    if (context.mounted)
      PrismToast.show(
        context,
        message: serverErrorText(context, e),
        icon: PhosphorIcons.warning(),
      );
    return false;
  }
}

Future<void> showConnectSheet(BuildContext context) => PrismSheet.show(
  context: context,
  title: tr(
    context,
    'Connect to a Prism Social server',
    'Conectar a un servidor de Prism Social',
  ),
  builder: (ctx) => const _ConnectSheet(),
);

class _ConnectSheet extends ConsumerStatefulWidget {
  const _ConnectSheet();
  @override
  ConsumerState<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends ConsumerState<_ConnectSheet> {
  final _url = TextEditingController();
  final _invite = TextEditingController();
  late bool _bring = ref.read(socialProfilesProvider).isNotEmpty;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = ref.watch(socialProfilesProvider);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              context,
              'Use the address of a Prism Social server you or someone you trust runs (for example one deployed on Railway).',
              'Usa la dirección de un servidor de Prism Social que tú o alguien de confianza gestione (por ejemplo, en Railway).',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _url,
            labelText: tr(context, 'Server address', 'Dirección del servidor'),
            hintText: 'prism-social.up.railway.app',
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          const SizedBox(height: 10),
          PrismTextField(
            controller: _invite,
            labelText: tr(
              context,
              'Invite code (if the server needs one)',
              'Código de invitación (si el servidor lo pide)',
            ),
          ),
          if (local.isNotEmpty)
            PrismSwitchRow(
              title: tr(
                context,
                'Bring my system profiles',
                'Llevar mis perfiles de sistema',
              ),
              subtitle: tr(
                context,
                'Recreates ${local.length} profile(s) and their alter profiles on the server. Friends, messages and posts between your own systems stay on this device.',
                'Recrea ${local.length} perfil(es) y sus alters en el servidor. Amistades, mensajes y publicaciones entre tus sistemas se quedan en el dispositivo.',
              ),
              value: _bring,
              padding: const EdgeInsets.symmetric(vertical: 8),
              onChanged: (v) => setState(() => _bring = v),
            ),
          const SizedBox(height: 6),
          Text(
            tr(
              context,
              'Only your Social profiles, friends, messages and posts go to the server. Your other Prism data stays private.',
              'Solo tus perfiles sociales, amigos, mensajes y publicaciones van al servidor. El resto de Prism sigue privado.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          PrismButton(
            label: tr(context, 'Connect', 'Conectar'),
            tone: PrismButtonTone.filled,
            isLoading: _busy,
            onPressed: () async {
              if (_busy || _url.text.trim().isEmpty) return;
              setState(() => _busy = true);
              final nav = Navigator.of(context);
              final ok = await _run(
                context,
                () => connectToSocialServer(
                  ref.read,
                  url: _url.text,
                  inviteCode: _invite.text.trim(),
                  bringProfiles: _bring,
                ),
                success: tr(context, 'Connected', 'Conectado'),
              );
              if (!mounted) return;
              setState(() => _busy = false);
              if (ok) nav.pop();
            },
          ),
        ],
      ),
    );
  }
}

/// Small honest banner for screens that mention where Social lives.
class SocialConnectionNote extends ConsumerWidget {
  const SocialConnectionNote({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(socialConnectionProvider);
    return Text(
      conn == null
          ? tr(
              context,
              'Social is on this device: it works between the systems on your Prism account. Connect to a Prism Social server to reach other people.',
              'Social está en este dispositivo: funciona entre los sistemas de tu cuenta. Conéctate a un servidor de Prism Social para llegar a otras personas.',
            )
          : tr(
              context,
              'Connected to ${conn.host}.',
              'Conectado a ${conn.host}.',
            ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Re-exported for the onboarding screen.
Widget connectButton(BuildContext context) => PrismButton(
  label: tr(context, 'Connect to a server instead', 'Conectar a un servidor'),
  icon: PhosphorIcons.globe(),
  onPressed: () => showConnectSheet(context),
);
