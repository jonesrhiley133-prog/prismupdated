import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/launch/launch_overlay.dart';
import 'package:prism_plurality/features/launch/launch_settings.dart';
import 'package:prism_plurality/features/settings/providers/settings_providers.dart';
import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Settings › Appearance › Launch experience.
class LaunchSettingsScreen extends ConsumerStatefulWidget {
  const LaunchSettingsScreen({super.key});
  @override
  ConsumerState<LaunchSettingsScreen> createState() => _LaunchSettingsScreenState();
}

class _LaunchSettingsScreenState extends ConsumerState<LaunchSettingsScreen> {
  late final _custom = TextEditingController(text: ref.read(launchSettingsProvider).customGreeting);
  int _replay = 0;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _set(LaunchSettings s) => ref.read(launchSettingsProvider.notifier).set(s);

  void _preview() {
    LaunchBoot.clock
      ..reset()
      ..start();
    setState(() => _replay++);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(launchSettingsProvider);
    final theme = Theme.of(context);
    final es = Localizations.localeOf(context).languageCode == 'es';
    final name = ref.watch(systemSettingsProvider).value?.systemName ?? '';
    final fronter = ref.watch(currentFronterProvider).value;
    String label(GreetingPreset p) => switch (p) {
      GreetingPreset.custom => tr(context, 'Custom greeting', 'Saludo personalizado'),
      GreetingPreset.none => tr(context, 'No greeting', 'Sin saludo'),
      GreetingPreset.timeOfDay => tr(context, 'Good morning / afternoon / evening', 'Buenos días / tardes / noches'),
      _ => buildGreeting(preset: p, custom: '', systemName: name, es: es),
    };

    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Launch experience', 'Pantalla de inicio')),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PrismShapes.of(context).radius(PrismTokens.radiusLarge)),
              child: SizedBox(
                height: 300,
                child: LaunchBackdrop(child: s.enabled ? LaunchMark(key: ValueKey('$_replay|${s.toJson()}')) : Text(tr(context, 'Launch animation is off', 'La animación de inicio está desactivada'), style: theme.textTheme.bodyMedium)),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: PrismButton(icon: PhosphorIcons.play(), label: tr(context, 'Replay preview', 'Repetir vista previa'), onPressed: _preview)),
            PrismSectionHeader(title: tr(context, 'ANIMATION', 'ANIMACIÓN')),
            PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                PrismSwitchRow(title: tr(context, 'Launch animation', 'Animación de inicio'), subtitle: tr(context, 'Never delays Prism: the app loads at the same time.', 'Nunca retrasa Prism: la app carga al mismo tiempo.'), value: s.enabled, onChanged: (v) => _set(s.copyWith(enabled: v))),
                PrismSwitchRow(title: tr(context, 'Skip on quick reopen', 'Omitir al reabrir enseguida'), subtitle: tr(context, 'If Prism was closed less than two minutes ago.', 'Si Prism se cerró hace menos de dos minutos.'), value: s.skipQuickReopen, onChanged: (v) => _set(s.copyWith(skipQuickReopen: v))),
                PrismSwitchRow(title: tr(context, 'Reduced motion', 'Movimiento reducido'), subtitle: tr(context, 'A gentle fade with no movement. Also follows your device setting.', 'Un fundido suave sin movimiento. También sigue el ajuste del dispositivo.'), value: s.reducedMotion, onChanged: (v) => _set(s.copyWith(reducedMotion: v))),
              ]),
            ),
            const SizedBox(height: 12),
            Text(tr(context, 'Style', 'Estilo'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            PrismSegmentedControl<LaunchStyle>(
              segments: [
                PrismSegment(value: LaunchStyle.assemble, label: tr(context, 'Assemble', 'Ensamblar')),
                PrismSegment(value: LaunchStyle.fade, label: tr(context, 'Fade', 'Fundido')),
                PrismSegment(value: LaunchStyle.minimal, label: tr(context, 'Minimal', 'Mínimo')),
              ],
              selected: s.style,
              onChanged: (v) => _set(s.copyWith(style: v)),
            ),
            const SizedBox(height: 12),
            Text(tr(context, 'Speed', 'Velocidad'), style: theme.textTheme.labelLarge),
            Row(children: [
              Text(tr(context, 'Slower', 'Más lenta'), style: theme.textTheme.bodySmall),
              Expanded(child: Slider(value: s.speed, min: 0.6, max: 1.6, divisions: 10, label: '${s.duration.inMilliseconds} ms', onChanged: (v) => _set(s.copyWith(speed: v)))),
              Text(tr(context, 'Faster', 'Más rápida'), style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: 4),
            Text(tr(context, 'Logo', 'Logo'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            PrismSegmentedControl<LaunchLogo>(
              segments: [
                PrismSegment(value: LaunchLogo.filled, label: tr(context, 'Filled', 'Relleno')),
                PrismSegment(value: LaunchLogo.outline, label: tr(context, 'Outline', 'Contorno')),
                PrismSegment(value: LaunchLogo.tile, label: tr(context, 'App icon', 'Icono')),
              ],
              selected: s.logo,
              onChanged: (v) => _set(s.copyWith(logo: v)),
            ),
            const SizedBox(height: 12),
            Text(tr(context, 'Background', 'Fondo'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            PrismSegmentedControl<LaunchBackground>(
              segments: [
                PrismSegment(value: LaunchBackground.theme, label: tr(context, 'My theme', 'Mi tema')),
                PrismSegment(value: LaunchBackground.prism, label: tr(context, 'Prism colours', 'Colores de Prism')),
              ],
              selected: s.background,
              onChanged: (v) => _set(s.copyWith(background: v)),
            ),
            PrismSectionHeader(title: tr(context, 'GREETING', 'SALUDO')),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final p in GreetingPreset.values)
                  PrismListRow(
                    dense: true,
                    title: Text(label(p)),
                    trailing: s.greeting == p ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: theme.colorScheme.primary) : null,
                    onTap: () => _set(s.copyWith(greeting: p)),
                  ),
              ]),
            ),
            if (s.greeting == GreetingPreset.custom) ...[
              const SizedBox(height: 10),
              PrismTextField(
                controller: _custom,
                labelText: tr(context, 'Your greeting', 'Tu saludo'),
                hintText: tr(context, 'Hi {primary_fronter}! Happy {day_of_week}', '¡Hola {primary_fronter}! Feliz {day_of_week}'),
                onChanged: (v) => _set(s.copyWith(customGreeting: v)),
              ),
              const SizedBox(height: 6),
              Text(
                tr(context, 'You can use {system_name}, {primary_fronter}, {time_of_day}, {date} and {day_of_week}.', 'Puedes usar {system_name}, {primary_fronter}, {time_of_day}, {date} y {day_of_week}.'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '→ ${buildGreeting(preset: GreetingPreset.custom, custom: s.customGreeting, systemName: name, primaryFronter: fronter?.name, es: es)}',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              margin: const EdgeInsets.only(top: 12),
              child: PrismSwitchRow(title: tr(context, 'Show the system picture', 'Mostrar la imagen del sistema'), value: s.showAvatar, onChanged: (v) => _set(s.copyWith(showAvatar: v))),
            ),
          ],
        ),
      ),
    );
  }
}
