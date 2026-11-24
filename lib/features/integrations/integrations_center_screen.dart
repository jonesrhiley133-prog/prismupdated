import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/account/account_core.dart';
import 'package:prism_plurality/core/services/notification_providers.dart';
import 'package:prism_plurality/core/sync/prism_sync_providers.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/providers/contact_providers.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
import 'package:prism_plurality/features/pluralkit/providers/pluralkit_providers.dart';
import 'package:prism_plurality/features/prism_social/social_remote.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

enum _State { connected, attention, off, fileOnly, unavailable }

/// Every outside connection in one place, with an honest status for each.
class IntegrationsCenterScreen extends ConsumerWidget {
  const IntegrationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthSettingsProvider);
    final syncOn = ref.watch(syncEnabledProvider);
    final pk = ref.watch(pluralKitSyncProvider);
    final social = ref.watch(socialConnectionProvider);
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final deviceContacts = contacts.where((c) => c.source != 'manual').length;
    final notif = ref.watch(notificationPermissionProvider).value;
    final fmt = DateFormat.MMMd().add_jm();
    final account = ref.watch(activeAccountProvider);

    String? ago(DateTime? t) => t == null
        ? null
        : tr(
            context,
            'Last synced ${fmt.format(t.toLocal())}',
            'Última sincronización ${fmt.format(t.toLocal())}',
          );

    final healthName = kIsWeb
        ? 'Health Connect / Apple Health'
        : (Theme.of(context).platform == TargetPlatform.iOS
              ? 'Apple Health'
              : 'Health Connect');
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Integrations', 'Integraciones'),
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(
              title: tr(context, 'CONNECTED SERVICES', 'SERVICIOS CONECTADOS'),
            ),
            _Card(
              children: [
                _Row(
                  icon: Icons.favorite_outline,
                  title: healthName,
                  state: kIsWeb
                      ? _State.unavailable
                      : (health.connected
                            ? (health.lastError != null
                                  ? _State.attention
                                  : _State.connected)
                            : _State.off),
                  detail: kIsWeb
                      ? tr(
                          context,
                          'Available in the Android and iPhone apps.',
                          'Disponible en las apps de Android y iPhone.',
                        )
                      : health.connected
                      ? [
                          ago(health.lastSync) ??
                              tr(
                                context,
                                'Not synced yet',
                                'Aún sin sincronizar',
                              ),
                          '${health.categories.length} ${tr(context, 'data types', 'tipos de datos')}',
                          if (health.sourcesSeen.isNotEmpty)
                            health.sourcesSeen.take(3).join(', '),
                        ].join(' · ')
                      : tr(
                          context,
                          'Workouts, steps, heart rate, sleep and periods — from Samsung Health, Fitbit, Garmin, Oura and other apps that share with it.',
                          'Entrenamientos, pasos, pulso, sueño y periodos — de Samsung Health, Fitbit, Garmin, Oura y otras apps que comparten con él.',
                        ),
                  onTap: kIsWeb
                      ? null
                      : () =>
                            context.go('${AppRoutePaths.fitness}/integrations'),
                ),
                _Row(
                  icon: Icons.cloud_outlined,
                  title: tr(context, 'Prism account & cloud backup', 'Cuenta de Prism y copia en la nube'),
                  state: account != null ? (account.backupKey == null ? _State.attention : _State.connected) : _State.off,
                  detail: account != null
                      ? [account.username, account.lastBackupAt == null ? tr(context, 'no backup yet', 'sin copia aún') : tr(context, 'last backup ${fmt.format(account.lastBackupAt!.toLocal())}', 'última copia ${fmt.format(account.lastBackupAt!.toLocal())}')].join(' · ')
                      : tr(context, 'Optional. End-to-end encrypted backups you can restore anywhere.', 'Opcional. Copias cifradas de extremo a extremo.'),
                  onTap: () => context.push(AppRoutePaths.account),
                ),
                _Row(
                  icon: Icons.sync,
                  title: 'Prism Sync',
                  state: syncOn ? _State.connected : _State.off,
                  detail: syncOn
                      ? tr(
                          context,
                          'End-to-end encrypted sync between your devices is on.',
                          'La sincronización cifrada de extremo a extremo está activa.',
                        )
                      : tr(
                          context,
                          'Sync your data between devices, end-to-end encrypted. No account needed.',
                          'Sincroniza tus datos entre dispositivos, cifrados de extremo a extremo. Sin cuenta.',
                        ),
                  onTap: () => context.push(AppRoutePaths.settingsSync),
                ),
                _Row(
                  icon: Icons.hub_outlined,
                  title: 'PluralKit',
                  state: pk.isConnected
                      ? (pk.syncError != null
                            ? _State.attention
                            : _State.connected)
                      : _State.off,
                  detail: pk.isConnected
                      ? (pk.syncError ??
                            (pk.syncStatus.isEmpty
                                ? tr(context, 'Connected', 'Conectado')
                                : pk.syncStatus))
                      : tr(
                          context,
                          'Two-way sync of members, groups and switches.',
                          'Sincronización de miembros, grupos y cambios.',
                        ),
                  onTap: () => context.push(AppRoutePaths.settingsPluralkit),
                ),
                _Row(
                  icon: Icons.forum_outlined,
                  title: 'Prism Social',
                  state: social != null ? _State.connected : _State.off,
                  detail: social != null
                      ? tr(
                          context,
                          'Connected to ${social.host}',
                          'Conectado a ${social.host}',
                        )
                      : tr(
                          context,
                          'On this device only. Connect a server to post with friends.',
                          'Solo en este dispositivo. Conecta un servidor para publicar con amigos.',
                        ),
                  onTap: () => context.go(AppRoutePaths.prismSocial),
                ),
                _Row(
                  icon: Icons.contacts_outlined,
                  title: tr(
                    context,
                    'Device contacts',
                    'Contactos del dispositivo',
                  ),
                  state: kIsWeb
                      ? _State.unavailable
                      : (deviceContacts > 0 ? _State.connected : _State.off),
                  detail: deviceContacts > 0
                      ? tr(
                          context,
                          '$deviceContacts imported (birthdays included)',
                          '$deviceContacts importados (con cumpleaños)',
                        )
                      : tr(
                          context,
                          'Import people and their birthdays.',
                          'Importa personas y sus cumpleaños.',
                        ),
                  onTap: () => context.go(AppRoutePaths.contacts),
                ),
                _Row(
                  icon: Icons.notifications_outlined,
                  title: tr(context, 'Notifications', 'Notificaciones'),
                  state: kIsWeb
                      ? _State.unavailable
                      : (notif == true ? _State.connected : _State.attention),
                  detail: notif == true
                      ? tr(context, 'Allowed', 'Permitidas')
                      : tr(
                          context,
                          'Not allowed — reminders can\'t be delivered.',
                          'No permitidas — los recordatorios no llegarán.',
                        ),
                  onTap: () =>
                      context.push(AppRoutePaths.settingsNotifications),
                ),
              ],
            ),
            PrismSectionHeader(
              title: tr(
                context,
                'IMPORT FROM A FILE',
                'IMPORTAR DESDE ARCHIVO',
              ),
            ),
            _Card(
              children: [
                _Row(
                  icon: Icons.water_drop_outlined,
                  title: tr(context, 'Cycle history', 'Historial del ciclo'),
                  state: _State.fileOnly,
                  detail: tr(
                    context,
                    'Clue export, CSV or JSON from Flo, Stardust and other trackers.',
                    'Exportación de Clue, CSV o JSON de Flo, Stardust y otras apps.',
                  ),
                  onTap: () => context.push(AppRoutePaths.cycleImport),
                ),
                _Row(
                  icon: Icons.directions_run,
                  title: tr(
                    context,
                    'Workouts & daily activity',
                    'Entrenamientos y actividad',
                  ),
                  state: _State.fileOnly,
                  detail: tr(
                    context,
                    'Apple Health, Google Fit (Takeout) and Samsung Health exports.',
                    'Exportaciones de Apple Health, Google Fit (Takeout) y Samsung Health.',
                  ),
                  onTap: () =>
                      context.go('${AppRoutePaths.fitness}/integrations'),
                ),
                _Row(
                  icon: Icons.upload_file_outlined,
                  title: tr(
                    context,
                    'Prism, Simply Plural & PluralKit data',
                    'Datos de Prism, Simply Plural y PluralKit',
                  ),
                  state: _State.fileOnly,
                  detail: tr(
                    context,
                    'Full data imports (.json, .prism).',
                    'Importaciones completas (.json, .prism).',
                  ),
                  onTap: () => context.push(AppRoutePaths.importCenter),
                ),
              ],
            ),
            PrismSectionHeader(
              title: tr(context, 'NOT AVAILABLE YET', 'AÚN NO DISPONIBLE'),
            ),
            _Card(
              children: [
                for (final (name, why) in [
                  (
                    'Spotify, YouTube Music, SoundCloud',
                    tr(
                      context,
                      'These need a registered developer app and sign-in that Prism doesn\'t have yet.',
                      'Requieren una app de desarrollador registrada e inicio de sesión que Prism aún no tiene.',
                    ),
                  ),
                  (
                    'Fitbit, Garmin, Oura (direct)',
                    tr(
                      context,
                      'Use Health Connect or Apple Health instead — these apps already share there.',
                      'Usa Health Connect o Apple Health — estas apps ya comparten ahí.',
                    ),
                  ),
                  (
                    'Flo, Clue, Stardust (live sync)',
                    tr(
                      context,
                      'No public sync. Import their export file above, or sync periods through Health Connect / Apple Health.',
                      'Sin sincronización pública. Importa su archivo arriba o sincroniza periodos con Health Connect / Apple Health.',
                    ),
                  ),
                ])
                  _Row(
                    icon: Icons.block_outlined,
                    title: name,
                    state: _State.unavailable,
                    detail: why,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PrismSurface(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 56),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.state,
    required this.detail,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final _State state;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (state) {
      _State.connected => (tr(context, 'Connected', 'Conectado'), Colors.green),
      _State.attention => (
        tr(context, 'Needs attention', 'Requiere atención'),
        Colors.orange,
      ),
      _State.off => (tr(context, 'Not connected', 'Sin conectar'), cs.outline),
      _State.fileOnly => (tr(context, 'File import', 'Archivo'), cs.primary),
      _State.unavailable => (
        tr(context, 'Unavailable', 'No disponible'),
        cs.outline,
      ),
    };
    return PrismListRow(
      leading: Icon(
        icon,
        color: state == _State.unavailable ? cs.outline : cs.primary,
      ),
      title: Text(title),
      subtitle: Text(detail),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
