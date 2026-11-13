import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/demo/demo_mode.dart';
import 'package:prism_plurality/features/demo/demo_seeder.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

String demoDurationLabel(BuildContext c, String k) => switch (k) {
  '1w' => tr(c, 'One week', 'Una semana'),
  '1m' => tr(c, 'One month', 'Un mes'),
  '6m' => tr(c, 'Six months', 'Seis meses'),
  '1y' => tr(c, 'One year', 'Un año'),
  '3y' => tr(c, 'Three years', 'Tres años'),
  _ => k,
};

/// Runs the demo seeder before the app appears when a fresh demo starts.
class DemoSeedGate extends ConsumerStatefulWidget {
  const DemoSeedGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<DemoSeedGate> createState() => _DemoSeedGateState();
}

class _DemoSeedGateState extends ConsumerState<DemoSeedGate> {
  bool _ready = !DemoMode.active;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!_ready) _seed();
  }

  Future<void> _seed() async {
    final prefs = await SharedPreferences.getInstance();
    if (DemoMode.seeded(prefs)) {
      setState(() => _ready = true);
      return;
    }
    try {
      final days = demoDurations[DemoMode.duration(prefs)] ?? 30;
      await DemoSeeder(ref, days: days, onProgress: (p, _) {
        if (mounted) setState(() => _progress = p);
      }).run();
      await DemoMode.markSeeded(prefs);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8E7CC3), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF8E7CC3), brightness: Brightness.dark, useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(_error == null ? 'Preparing the demo…' : 'The demo could not be prepared', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (_error == null) LinearProgressIndicator(value: _progress) else Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('Your real data is kept separately and is not changed.', textAlign: TextAlign.center),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    PrismButton(
                      label: 'Leave Demo Mode',
                      tone: PrismButtonTone.filled,
                      onPressed: () async {
                        await DemoMode.exit(await SharedPreferences.getInstance());
                        if (context.mounted) AppRestartScope.restart(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin strip shown at the top of every screen in Demo Mode.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DemoMode.active) return child;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        child,
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: false,
            child: Center(
              child: Material(
                color: const Color(0xFFF2A93B),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  onTap: () => confirmExitDemo(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: Text(
                      tr(context, 'DEMO MODE · sample data · tap to exit', 'MODO DEMO · datos de ejemplo · toca para salir'),
                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Wraps screens that must not run on demo data (sync, PluralKit, resets).
class DemoGuard extends StatelessWidget {
  const DemoGuard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DemoMode.active) return child;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Not available in Demo Mode', 'No disponible en el modo demo'), showBackButton: true),
      body: EmptyState(
        icon: Icon(PhosphorIcons.shieldCheck()),
        title: tr(context, 'This is turned off in Demo Mode', 'Esto está desactivado en el modo demo'),
        subtitle: tr(context, 'Sync, PluralKit and data resets only work with your real data, so sample data can never reach your accounts or devices.',
            'La sincronización, PluralKit y los reinicios solo funcionan con tus datos reales, para que los datos de ejemplo nunca lleguen a tus cuentas o dispositivos.'),
        actionLabel: tr(context, 'Leave Demo Mode', 'Salir del modo demo'),
        onAction: () => confirmExitDemo(context),
      ),
    );
  }
}

Future<void> confirmExitDemo(BuildContext context) async {
  final ok = await PrismDialog.confirm(
    context: context,
    title: tr(context, 'Leave Demo Mode?', '¿Salir del modo demo?'),
    message: tr(context, 'Prism will reload with your real alters, records, settings and dashboard exactly as you left them. The demo data is kept in case you come back.',
        'Prism se recargará con tus alters, registros, ajustes y panel reales tal como los dejaste. Los datos de demostración se guardan por si vuelves.'),
    confirmLabel: tr(context, 'Leave demo', 'Salir de la demo'),
    cancelLabel: context.l10n.cancel,
  );
  if (!ok || !context.mounted) return;
  await DemoMode.exit(await SharedPreferences.getInstance());
  if (context.mounted) AppRestartScope.restart(context);
}

class DemoModeScreen extends StatefulWidget {
  const DemoModeScreen({super.key});
  @override
  State<DemoModeScreen> createState() => _DemoModeScreenState();
}

class _DemoModeScreenState extends State<DemoModeScreen> {
  String _duration = '1m';
  bool _hasDemo = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _duration = DemoMode.duration(p);
        _hasDemo = DemoMode.seeded(p);
      });
    });
  }

  Future<void> _enter({required bool fresh}) async {
    final ok = await PrismDialog.confirm(
      context: context,
      title: tr(context, 'Switch to Demo Mode?', '¿Cambiar al modo demo?'),
      message: tr(
        context,
        'Prism will reload with ${fresh ? 'a fresh ${demoDurationLabel(context, _duration).toLowerCase()} of' : 'your previous'} sample data. Your real data stays in its own file and is not changed or synced. Sync and PluralKit are paused until you leave.',
        'Prism se recargará con ${fresh ? 'nuevos datos de ejemplo (${demoDurationLabel(context, _duration).toLowerCase()})' : 'tus datos de ejemplo anteriores'}. Tus datos reales siguen en su propio archivo y no se modifican ni se sincronizan. La sincronización y PluralKit se pausan hasta que salgas.',
      ),
      confirmLabel: tr(context, 'Start demo', 'Iniciar demo'),
      cancelLabel: context.l10n.cancel,
    );
    if (!ok || !mounted) return;
    await DemoMode.enter(await SharedPreferences.getInstance(), _duration, freshData: fresh || !_hasDemo);
    if (mounted) AppRestartScope.restart(context);
  }

  Future<void> _regenerate() async {
    final ok = await PrismDialog.confirm(
      context: context,
      title: tr(context, 'Replace the demo data?', '¿Reemplazar los datos de demostración?'),
      message: tr(context, 'All sample data (including changes you made in the demo) is replaced with a new ${demoDurationLabel(context, _duration).toLowerCase()} set. Real data is not affected.',
          'Todos los datos de ejemplo (incluidos tus cambios en la demo) se sustituyen por un nuevo conjunto. Los datos reales no se ven afectados.'),
      destructive: true,
      confirmLabel: tr(context, 'Replace', 'Reemplazar'),
      cancelLabel: context.l10n.cancel,
    );
    if (!ok || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    // Leave without restoring twice: exit restores real prefs, then re-enter fresh.
    await DemoMode.exit(prefs, keepDemoData: false);
    await DemoMode.enter(prefs, _duration, freshData: false);
    await prefs.setBool('prism.demo.seeded', false);
    await prefs.setBool('prism.demo.wipeOnStart', true);
    if (mounted) AppRestartScope.restart(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = DemoMode.active;
    return PrismPageScaffold(
      topBar: PrismTopBar(title: tr(context, 'Demo Mode', 'Modo demo'), showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      body: ListView(
        padding: EdgeInsets.only(top: 8, bottom: NavBarInset.of(context) + 24),
        children: [
          PrismSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(active ? PhosphorIcons.playCircle(PhosphorIconsStyle.fill) : PhosphorIcons.flask(), color: const Color(0xFFF2A93B)),
                    const SizedBox(width: 8),
                    Text(active ? tr(context, 'Demo Mode is on', 'El modo demo está activado') : tr(context, 'Explore with sample data', 'Explora con datos de ejemplo'), style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    context,
                    'Demo Mode fills Prism with a realistic sample system — seven alters with fronting and co-fronting history, moods, journal and dream entries, meals and hydration, sleep, calendar events, statuses, availability, connection maps, scrapbooks and analytics. Everything is interactive: edit and experiment freely.',
                    'El modo demo llena Prism con un sistema de ejemplo realista: siete alters con historial de frente y co-frente, ánimos, diario y sueños, comidas e hidratación, sueño, eventos, estados, disponibilidad, mapas, álbumes y análisis. Todo es interactivo: edita y experimenta con libertad.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'Your real data lives in a separate file and is never changed, deleted or synced while the demo is on. Leaving restores your alters, records, settings and dashboard exactly.',
                      'Tus datos reales viven en un archivo aparte y nunca se cambian, borran ni sincronizan durante la demo. Al salir se restauran tus alters, registros, ajustes y panel.'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TrackerLabel(tr(context, 'How much history', 'Cuánto historial')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final k in demoDurations.keys) PrismChip(label: demoDurationLabel(context, k), selected: _duration == k, onTap: () => setState(() => _duration = k))],
          ),
          const SizedBox(height: 16),
          if (!active) ...[
            PrismButton(label: tr(context, 'Start a fresh demo', 'Iniciar una demo nueva'), icon: PhosphorIcons.play(), tone: PrismButtonTone.filled, onPressed: () => _enter(fresh: true)),
            if (_hasDemo) ...[
              const SizedBox(height: 8),
              PrismButton(label: tr(context, 'Continue previous demo', 'Continuar la demo anterior'), icon: PhosphorIcons.arrowClockwise(), onPressed: () => _enter(fresh: false)),
            ],
          ] else ...[
            PrismButton(label: tr(context, 'Leave Demo Mode', 'Salir del modo demo'), icon: PhosphorIcons.signOut(), tone: PrismButtonTone.filled, onPressed: () => confirmExitDemo(context)),
            const SizedBox(height: 8),
            PrismButton(label: tr(context, 'Regenerate demo data', 'Regenerar datos de demostración'), icon: PhosphorIcons.arrowsClockwise(), onPressed: _regenerate),
          ],
          const SizedBox(height: 16),
          Text(
            tr(context, 'While the demo is on: sync, PluralKit and data resets are paused, and a “Demo Mode” strip shows at the top of the screen.',
                'Durante la demo: la sincronización, PluralKit y los reinicios de datos están en pausa y se muestra una franja «Modo demo» arriba.'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
