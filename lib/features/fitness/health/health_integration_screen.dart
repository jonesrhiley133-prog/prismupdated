import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fitness/health/health_sync.dart';
import 'package:prism_plurality/features/fitness/utils/fitness.dart';
import 'package:prism_plurality/features/fitness/views/fitness_labels.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

final healthAvailabilityProvider = FutureProvider.autoDispose<String>((ref) => ref.read(healthGatewayProvider).availability());

String platformName(BuildContext c, HealthGateway g) => g.ios ? 'Apple Health' : 'Health Connect';

/// Fitness › Integrations: connection, permissions, sync settings,
/// imported records and troubleshooting.
class HealthIntegrationScreen extends ConsumerStatefulWidget {
  const HealthIntegrationScreen({super.key});
  @override
  ConsumerState<HealthIntegrationScreen> createState() => _HealthIntegrationScreenState();
}

class _HealthIntegrationScreenState extends ConsumerState<HealthIntegrationScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final r = await ref.read(healthSyncProvider).sync();
    if (!mounted) return;
    setState(() => _syncing = false);
    PrismToast.show(
      context,
      message: r.error != null
          ? tr(context, 'Sync failed — see Troubleshooting below.', 'Error al sincronizar: mira Solución de problemas abajo.')
          : tr(context, '${r.workouts} new workouts · ${r.duplicates} duplicates skipped · ${r.days} days updated', '${r.workouts} entrenamientos nuevos · ${r.duplicates} duplicados omitidos · ${r.days} días actualizados'),
      icon: r.error == null ? PhosphorIcons.check() : PhosphorIcons.warning(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = ref.watch(healthGatewayProvider);
    final s = ref.watch(healthSettingsProvider);
    final avail = ref.watch(healthAvailabilityProvider);
    final df = DateFormat.yMMMd(context.dateLocale).add_jm();
    final imported = [for (final r in ref.watch(trackerKindProvider(TrackerKind.fitnessWorkout)).value ?? const <TrackerRecord>[]) if (r.flag('imported')) r];
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Health integrations', 'Integraciones de salud'), showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, NavBarInset.of(context) + 32),
        children: [
          ClampedBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!g.supported)
                  PrismSurface(child: Text(tr(context, 'Health integrations work on Android (Health Connect) and iPhone (Apple Health). This device doesn’t support them, but you can still log workouts by hand.', 'Las integraciones funcionan en Android (Health Connect) y iPhone (Apple Health). Este dispositivo no las admite, pero puedes registrar entrenamientos a mano.')))
                else ...[
                  PrismSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.heartbeat(), color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(child: Text(platformName(context, g), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                            Text(
                              s.connected ? tr(context, 'Connected', 'Conectado') : tr(context, 'Not connected', 'Sin conectar'),
                              style: theme.textTheme.labelMedium?.copyWith(color: s.connected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        avail.when(
                          data: (a) => Text(switch (a) {
                            'available' => tr(context, '${platformName(context, g)} is available on this device.', '${platformName(context, g)} está disponible en este dispositivo.'),
                            'updateRequired' => tr(context, 'Health Connect needs an update.', 'Health Connect necesita actualizarse.'),
                            'notInstalled' => tr(context, 'Health Connect isn’t installed yet.', 'Health Connect aún no está instalado.'),
                            _ => tr(context, 'Not supported here.', 'No compatible aquí.'),
                          }, style: theme.textTheme.bodySmall),
                          loading: () => Text(tr(context, 'Checking…', 'Comprobando…'), style: theme.textTheme.bodySmall),
                          error: (e, _) => Text(tr(context, 'Couldn’t check availability.', 'No se pudo comprobar.'), style: theme.textTheme.bodySmall),
                        ),
                        if (s.lastSync != null) Text(tr(context, 'Last sync: ${df.format(s.lastSync!)}', 'Última sincronización: ${df.format(s.lastSync!)}'), style: theme.textTheme.bodySmall),
                        Text(tr(context, 'Imported workouts: ${s.imported} · duplicates skipped: ${s.duplicates}', 'Entrenamientos importados: ${s.imported} · duplicados omitidos: ${s.duplicates}'), style: theme.textTheme.bodySmall),
                        if (s.lastError != null && s.lastError != 'denied') Text(tr(context, 'Last error: ${s.lastError}', 'Último error: ${s.lastError}'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!s.connected) PrismButton(label: tr(context, 'Set up with the assistant', 'Configurar con el asistente'), icon: PhosphorIcons.sparkle(), tone: PrismButtonTone.filled, onPressed: () => showHealthAssistant(context)),
                            if (s.connected) PrismButton(label: tr(context, 'Sync now', 'Sincronizar ahora'), icon: PhosphorIcons.arrowsClockwise(), tone: PrismButtonTone.filled, isLoading: _syncing, onPressed: _syncing ? () {} : _syncNow),
                            if (s.connected)
                              PrismButton(
                                label: tr(context, 'Disconnect', 'Desconectar'),
                                tone: PrismButtonTone.destructive,
                                onPressed: () async {
                                  final ok = await PrismDialog.confirm(
                                    context: context,
                                    title: tr(context, 'Disconnect ${platformName(context, g)}?', '¿Desconectar ${platformName(context, g)}?'),
                                    message: tr(context, 'Syncing stops${g.ios ? '' : ' and Prism’s Health Connect access is revoked'}. Workouts already imported stay in Fitness unless you remove them below.', 'Se detiene la sincronización${g.ios ? '' : ' y se revoca el acceso de Prism a Health Connect'}. Lo ya importado se queda en Ejercicio salvo que lo quites abajo.'),
                                    destructive: true,
                                    confirmLabel: tr(context, 'Disconnect', 'Desconectar'),
                                    cancelLabel: context.l10n.cancel,
                                  );
                                  if (ok == true) await ref.read(healthSyncProvider).disconnect();
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (s.connected) ...[
                    const SizedBox(height: 16),
                    Text(tr(context, 'What Prism imports', 'Qué importa Prism'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    for (final c in HealthCategory.values)
                      PrismSwitchRow(
                        title: healthCategoryText(context, c),
                        subtitle: healthCategoryWhy(context, c),
                        value: s.categories.contains(c),
                        onChanged: (v) async {
                          final next = {...s.categories};
                          v ? next.add(c) : next.remove(c);
                          if (v) {
                            // New types need their own permission.
                            final ok = await ref.read(healthSyncProvider).connect(next);
                            if (!ok && context.mounted) PrismToast.show(context, message: tr(context, 'Permission wasn’t granted for that type.', 'No se concedió permiso para ese tipo.'));
                          } else {
                            await ref.read(healthSyncProvider).saveSettings({'categories': [for (final x in next) x.name]});
                          }
                        },
                      ),
                    PrismSwitchRow(title: tr(context, 'Sync automatically', 'Sincronizar automáticamente'), subtitle: tr(context, 'When Prism opens and every 30 minutes while it’s open.', 'Al abrir Prism y cada 30 minutos mientras está abierto.'), value: s.autoSync, onChanged: (v) => ref.read(healthSyncProvider).saveSettings({'autoSync': v})),
                    const SizedBox(height: 12),
                    Text(tr(context, 'Who imported activity belongs to', 'A quién pertenece la actividad importada'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(tr(context, 'Prism never assumes who was fronting. Imported activity is shared system activity unless you pick a default alter or assign each workout.', 'Prism nunca supone quién estaba al frente. La actividad importada es del sistema salvo que elijas un alter predeterminado o asignes cada entrenamiento.'), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    _AlterChoice(selected: s.defaultAlter, onChanged: (id) => ref.read(healthSyncProvider).saveSettings({'defaultAlter': id})),
                    if (s.sourcesSeen.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(tr(context, 'Apps sending data', 'Apps que envían datos'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(tr(context, 'Found in ${platformName(context, g)} records Prism was allowed to read.', 'Encontradas en los registros de ${platformName(context, g)} que Prism puede leer.'), style: theme.textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final src in s.sourcesSeen) PrismChip(label: src, selected: true, onTap: () {})]),
                    ],
                  ],
                  const SizedBox(height: 16),
                  _Troubleshooting(platform: platformName(context, g), ios: g.ios),
                  if (imported.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text(tr(context, 'Imported workouts', 'Entrenamientos importados'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                        PrismButton(
                          label: tr(context, 'Remove all imported', 'Quitar todo lo importado'),
                          tone: PrismButtonTone.destructive,
                          density: PrismControlDensity.compact,
                          onPressed: () async {
                            final ok = await PrismDialog.confirm(context: context, title: tr(context, 'Remove imported data?', '¿Quitar los datos importados?'), message: tr(context, 'Imported workouts and daily totals are removed from Prism (not from the health app). Workouts you logged yourself stay.', 'Se quitan de Prism los entrenamientos y totales importados (no de la app de salud). Los que registraste tú se quedan.'), destructive: true, confirmLabel: tr(context, 'Remove', 'Quitar'), cancelLabel: context.l10n.cancel);
                            if (ok == true) await ref.read(healthSyncProvider).removeImported();
                          },
                        ),
                      ],
                    ),
                    for (final w in imported.take(30)) _ImportedRow(w: w),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlterChoice extends ConsumerWidget {
  const _AlterChoice({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(userVisibleMemberListProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        PrismChip(label: tr(context, 'Shared system activity', 'Actividad del sistema'), selected: selected == null, onTap: () => onChanged(null)),
        for (final m in members) PrismChip(label: m.effectiveName(preferDisplayName: prefer), selected: selected == m.id, onTap: () => onChanged(m.id)),
      ],
    );
  }
}

class _ImportedRow extends ConsumerWidget {
  const _ImportedRow({required this.w});
  final TrackerRecord w;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat.MMMd(context.dateLocale).add_jm();
    final members = {for (final m in ref.watch(userVisibleMemberListProvider).value ?? const <Member>[]) m.id: m};
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final who = members[w.memberId]?.effectiveName(preferDisplayName: prefer) ?? tr(context, 'System', 'Sistema');
    return PrismListRow(
      dense: true,
      leading: Icon(PhosphorIcons.barbell(), size: 20),
      title: Text('${fitnessActivityLabel(context.l10n, w.str(FitField.activity) ?? 'other')} · ${w.integer(FitField.minutes) ?? 0} min'),
      subtitle: Text('${df.format(w.occurredAt ?? w.createdAt)} · ${tr(context, 'from ${w.str('source') ?? '?'}', 'de ${w.str('source') ?? '?'}')} · $who'),
      showChevron: true,
      onTap: () => _assign(context, ref, w),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref, TrackerRecord w) async {
    String? sel = w.memberId;
    await PrismSheet.show(
      context: context,
      title: tr(context, 'Imported workout', 'Entrenamiento importado'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr(ctx, 'From ${w.str('source') ?? '?'} (${w.str('sourceType') ?? ''}). Imported details stay as the health app recorded them.', 'De ${w.str('source') ?? '?'} (${w.str('sourceType') ?? ''}). Los datos importados quedan como los registró la app de salud.')),
              const SizedBox(height: 10),
              TrackerLabel(tr(ctx, 'Belongs to', 'Pertenece a')),
              _AlterChoice(selected: sel, onChanged: (id) => set(() => sel = id)),
              const SizedBox(height: 14),
              Row(
                children: [
                  PrismButton(
                    label: tr(ctx, 'Remove', 'Quitar'),
                    tone: PrismButtonTone.destructive,
                    onPressed: () async {
                      await ref.read(trackerNotifierProvider.notifier).delete(w.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                  const Spacer(),
                  PrismButton(
                    label: ctx.l10n.save,
                    tone: PrismButtonTone.filled,
                    onPressed: () async {
                      await ref.read(trackerNotifierProvider.notifier).save(w.copyWith(memberId: sel));
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Troubleshooting extends ConsumerWidget {
  const _Troubleshooting({required this.platform, required this.ios});
  final String platform;
  final bool ios;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(healthSettingsProvider);
    final avail = ref.watch(healthAvailabilityProvider).value;
    final tips = <(String, String)>[
      if (avail == 'notInstalled') ('Install Health Connect from the Play Store, then come back and connect.', 'Instala Health Connect desde Play Store y vuelve para conectar.'),
      if (avail == 'updateRequired') ('Update Health Connect in the Play Store.', 'Actualiza Health Connect en Play Store.'),
      if (s.lastError == 'denied') ('Permission was declined. Connect again and allow the types you want — or open ${ios ? 'Settings › Health › Data Access & Devices › Prism' : 'Health Connect › App permissions › Prism'}.', 'Se rechazó el permiso. Vuelve a conectar y permite los tipos que quieras, o abre ${ios ? 'Ajustes › Salud › Acceso a datos › Prism' : 'Health Connect › Permisos de apps › Prism'}.'),
      if (s.connected && s.imported == 0) ('No workouts yet? Make sure your fitness app (Samsung Health, Google Fit, Strava, Fitbit, Garmin, …) is set to share with $platform in its own settings.', '¿Sin entrenamientos? Asegúrate de que tu app de ejercicio (Samsung Health, Google Fit, Strava, Fitbit, Garmin…) comparta con $platform en sus ajustes.'),
      if (!ios) ('Health Connect only shares the last 30 days by default; Prism asks for history access so older workouts can be imported.', 'Health Connect solo comparte los últimos 30 días por defecto; Prism pide acceso al historial para importar lo anterior.'),
      if (s.lastError != null && s.lastError != 'denied') ('The last sync hit an error. Try “Sync now” again; if it keeps failing, disconnect and connect again.', 'La última sincronización falló. Prueba «Sincronizar ahora»; si sigue fallando, desconecta y vuelve a conectar.'),
      ('Prism can’t see which apps are installed. Apps appear here once they share data through $platform.', 'Prism no puede ver qué apps tienes instaladas. Aparecen aquí cuando comparten datos mediante $platform.'),
    ];
    return PrismSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(PhosphorIcons.lifebuoy(), size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(tr(context, 'Troubleshooting', 'Solución de problemas'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 6),
          for (final t in tips) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${tr(context, t.$1, t.$2)}', style: theme.textTheme.bodySmall)),
          if (avail == 'notInstalled' || avail == 'updateRequired') PrismButton(label: tr(context, 'Get Health Connect', 'Obtener Health Connect'), onPressed: () => ref.read(healthGatewayProvider).install()),
        ],
      ),
    );
  }
}

/// Step-by-step setup guide (not an AI model: it follows fixed steps and
/// checks the device's real status).
Future<void> showHealthAssistant(BuildContext context) => PrismSheet.showFullScreen(context: context, builder: (ctx, scroll) => _Assistant(scroll: scroll));

class _Assistant extends ConsumerStatefulWidget {
  const _Assistant({required this.scroll});
  final ScrollController scroll;
  @override
  ConsumerState<_Assistant> createState() => _AssistantState();
}

class _AssistantState extends ConsumerState<_Assistant> {
  int _step = 0;
  late Set<HealthCategory> _cats = {...ref.read(healthSettingsProvider).categories};
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    ref.read(healthSyncProvider).saveSettings({'assistantSeen': true});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = ref.watch(healthGatewayProvider);
    final avail = ref.watch(healthAvailabilityProvider);
    final s = ref.watch(healthSettingsProvider);
    final name = platformName(context, g);
    Widget bubble(String text) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
    );
    final steps = <Widget>[
      // 0: what it does
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bubble(tr(context, 'Hi! I can connect Fitness to $name so your workouts arrive on their own instead of being typed in.', '¡Hola! Puedo conectar Ejercicio con $name para que tus entrenamientos lleguen solos en lugar de escribirlos.')),
          bubble(tr(context, 'Apps like Samsung Health, Google Fit, Strava, Fitbit or Garmin share their data with $name. Prism then reads only the types you allow — nothing is shared back, and nothing connects without you approving it in the system screen.', 'Apps como Samsung Health, Google Fit, Strava, Fitbit o Garmin comparten datos con $name. Prism solo lee los tipos que permitas; no comparte nada y nada se conecta sin tu aprobación en la pantalla del sistema.')),
          bubble(tr(context, 'Imported workouts show where they came from, duplicates are skipped, and you choose whether they belong to the whole system or a specific alter.', 'Los entrenamientos importados indican su origen, se omiten duplicados y tú eliges si son de todo el sistema o de un alter.')),
        ],
      ),
      // 1: availability
      avail.when(
        loading: () => bubble(tr(context, 'Checking this device…', 'Comprobando este dispositivo…')),
        error: (e, _) => bubble(tr(context, 'I couldn’t check this device: $e', 'No pude comprobar el dispositivo: $e')),
        data: (a) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bubble(switch (a) {
              'available' => tr(context, 'Good news — $name is available here.', 'Buenas noticias: $name está disponible aquí.'),
              'notInstalled' => tr(context, 'Health Connect isn’t installed. Install it, then tap Check again.', 'Health Connect no está instalado. Instálalo y pulsa Comprobar de nuevo.'),
              'updateRequired' => tr(context, 'Health Connect needs an update first.', 'Primero hay que actualizar Health Connect.'),
              _ => tr(context, 'This device doesn’t support health integrations. You can keep logging workouts by hand.', 'Este dispositivo no admite integraciones de salud. Puedes seguir registrando a mano.'),
            }),
            if (a == 'notInstalled' || a == 'updateRequired')
              Wrap(spacing: 8, children: [
                PrismButton(label: tr(context, 'Get Health Connect', 'Obtener Health Connect'), onPressed: () => g.install()),
                PrismButton(label: tr(context, 'Check again', 'Comprobar de nuevo'), onPressed: () => ref.invalidate(healthAvailabilityProvider)),
              ]),
          ],
        ),
      ),
      // 2: choose data
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bubble(tr(context, 'What would you like to import? You can change this any time.', '¿Qué quieres importar? Puedes cambiarlo cuando quieras.')),
          for (final c in HealthCategory.values)
            PrismSwitchRow(title: healthCategoryText(context, c), subtitle: healthCategoryWhy(context, c), value: _cats.contains(c), onChanged: (v) => setState(() => v ? _cats.add(c) : _cats.remove(c))),
        ],
      ),
      // 3: permission
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bubble(tr(context, 'Next, $name will ask you to allow reading ${_cats.length} type${_cats.length == 1 ? '' : 's'}. Allow only what you’re comfortable with.', 'Ahora $name te pedirá permitir la lectura de ${_cats.length} tipo${_cats.length == 1 ? '' : 's'}. Permite solo lo que te parezca bien.')),
          if (_msg != null) bubble(_msg!),
          Align(
            alignment: Alignment.centerLeft,
            child: PrismButton(
              label: s.connected ? tr(context, 'Connected ✓', 'Conectado ✓') : tr(context, 'Ask for permission', 'Pedir permiso'),
              tone: PrismButtonTone.filled,
              isLoading: _busy,
              onPressed: _busy || _cats.isEmpty
                  ? () {}
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final ok = await ref.read(healthSyncProvider).connect(_cats);
                        setState(() => _msg = ok ? tr(context, 'Done — Prism can read the types you allowed.', 'Listo: Prism puede leer los tipos que permitiste.') : tr(context, 'Permission wasn’t granted. You can try again, or allow it later in $name.', 'No se concedió el permiso. Puedes reintentarlo o permitirlo después en $name.'));
                      } catch (e) {
                        setState(() => _msg = tr(context, 'Something went wrong: $e', 'Algo salió mal: $e'));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ),
        ],
      ),
      // 4: alter + first sync
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bubble(tr(context, 'Should imported activity count for the whole system, or a default alter? You can reassign any workout later.', '¿La actividad importada cuenta para todo el sistema o para un alter predeterminado? Puedes reasignar cualquier entrenamiento después.')),
          _AlterChoice(selected: s.defaultAlter, onChanged: (id) => ref.read(healthSyncProvider).saveSettings({'defaultAlter': id})),
          const SizedBox(height: 12),
          if (s.connected)
            Align(
              alignment: Alignment.centerLeft,
              child: PrismButton(
                label: tr(context, 'Import the last 30 days', 'Importar los últimos 30 días'),
                icon: PhosphorIcons.downloadSimple(),
                isLoading: _busy,
                onPressed: _busy
                    ? () {}
                    : () async {
                        setState(() => _busy = true);
                        final r = await ref.read(healthSyncProvider).sync();
                        if (!mounted) return;
                        setState(() {
                          _busy = false;
                          _msg = r.error != null ? tr(context, 'The sync hit an error: ${r.error}', 'La sincronización falló: ${r.error}') : tr(context, 'Imported ${r.workouts} workouts (${r.duplicates} duplicates skipped) and ${r.days} days of totals.', 'Importados ${r.workouts} entrenamientos (${r.duplicates} duplicados omitidos) y ${r.days} días de totales.');
                        });
                      },
              ),
            ),
          if (_msg != null && _step == 4) bubble(_msg!),
        ],
      ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Icon(PhosphorIcons.sparkle(), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(tr(context, 'Integration assistant', 'Asistente de integración'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              PrismTopBarAction(icon: AppIcons.close, tooltip: tr(context, 'Close', 'Cerrar'), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(tr(context, 'Step ${_step + 1} of ${steps.length}', 'Paso ${_step + 1} de ${steps.length}'), style: theme.textTheme.bodySmall)),
        Expanded(child: ListView(controller: widget.scroll, padding: const EdgeInsets.all(16), children: [steps[_step]])),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (_step > 0) PrismButton(label: tr(context, 'Back', 'Atrás'), onPressed: () => setState(() => _step--)),
                const Spacer(),
                if (_step < steps.length - 1)
                  PrismButton(
                    label: tr(context, 'Next', 'Siguiente'),
                    tone: PrismButtonTone.filled,
                    onPressed: (_step == 1 && avail.value != 'available') || (_step == 3 && !s.connected)
                        ? () {}
                        : () => setState(() {
                            _step++;
                            _msg = null;
                          }),
                    enabled: !((_step == 1 && avail.value != 'available') || (_step == 3 && !s.connected)),
                  )
                else
                  PrismButton(label: tr(context, 'Done', 'Hecho'), tone: PrismButtonTone.filled, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
