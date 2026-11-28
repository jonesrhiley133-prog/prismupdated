import 'package:prism_plurality/core/graphics/decor_clock.dart';
import 'package:prism_plurality/core/graphics/frame_monitor.dart';
import 'package:prism_plurality/core/graphics/graphics_engine.dart';
import 'package:prism_plurality/core/graphics/graphics_host.dart';
import 'package:prism_plurality/core/graphics/graphics_platform.dart';
import 'package:prism_plurality/core/graphics/graphics_prefs.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Graphics & Performance: presets, individual controls and live numbers.
/// Every control changes how Prism renders, immediately (the renderer
/// choice on Android applies at the next launch).
class GraphicsSettingsScreen extends ConsumerStatefulWidget {
  const GraphicsSettingsScreen({super.key});
  @override
  ConsumerState<GraphicsSettingsScreen> createState() =>
      _GraphicsSettingsScreenState();
}

class _GraphicsSettingsScreenState
    extends ConsumerState<GraphicsSettingsScreen> {
  late final Future<GraphicsDeviceInfo> _device = GraphicsPlatform.info();

  @override
  void initState() {
    super.initState();
    // Live numbers while this page is open.
    FrameMonitor.instance.watch();
  }

  @override
  void dispose() {
    FrameMonitor.instance.unwatch();
    super.dispose();
  }

  GraphicsPrefsNotifier get _n => ref.read(graphicsPrefsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(graphicsPrefsProvider);
    final q = ref.watch(graphicsEngineProvider);
    final theme = Theme.of(context);

    Widget select<T>(
      String label,
      T value,
      Map<T, String> options,
      ValueChanged<T> onChanged, {
      String? helper,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PrismSelect<T>(
        labelText: label,
        helperText: helper,
        value: value,
        items: [
          for (final e in options.entries)
            PrismSelectItem(value: e.key, label: e.value),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
    Map<Quality, String> qualities([bool withOff = true]) => {
      for (final x in Quality.values)
        if (withOff || x != Quality.off) x: x.label,
    };

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Graphics & Performance', 'Gráficos y rendimiento'),
        showBackButton: true,
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            Text(
              tr(
                context,
                'Prism keeps every effect; these settings change how hard the device works to draw them. Touch, typing, scrolling and navigation always come first — decorations slow down before the interface does.',
                'Prism conserva todos los efectos; esto cambia cuánto trabaja el dispositivo para dibujarlos. Tocar, escribir, desplazarse y navegar siempre van primero.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PrismSurface(
              child: ValueListenableBuilder<PerfSnapshot>(
                valueListenable: FrameMonitor.instance.snapshot,
                builder: (context, s, _) => DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  child: PerfReadout(s: s, q: q),
                ),
              ),
            ),
            if (q.level < 0.999 || q.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${tr(context, 'Running at', 'Funcionando al')} ${(q.level * 100).round()}%'
                  '${q.reason.isEmpty ? '' : ' — ${q.reason}'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            TrackerLabel(tr(context, 'Preset', 'Ajuste')),
            for (final preset in GraphicsPreset.values)
              if (preset != GraphicsPreset.custom)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PrismListRow(
                    selected: p.preset == preset,
                    leading: Icon(
                      p.preset == preset
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: p.preset == preset
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    title: Text(preset.label),
                    subtitle: Text(preset.description),
                    onTap: () => _n.applyPreset(preset),
                  ),
                ),
            if (p.preset == GraphicsPreset.custom)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tr(
                    context,
                    'Custom: you’ve changed individual settings below.',
                    'Personalizado: cambiaste ajustes individuales.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            TrackerLabel(tr(context, 'Display', 'Pantalla')),
            FutureBuilder<GraphicsDeviceInfo>(
              future: _device,
              builder: (context, snap) {
                final d = snap.data ?? const GraphicsDeviceInfo();
                final rates = {
                  0: tr(context, 'Device default', 'Predeterminado'),
                  for (final r in const [30, 60, 90, 120])
                    if (!d.supported ||
                        d.refreshRates.isEmpty ||
                        d.refreshRates.any((x) => (x - r).abs() < 3) ||
                        r <= (d.refreshRates.lastOrNull ?? 60))
                      r: '$r fps',
                };
                return select<int>(
                  tr(context, 'Target frame rate', 'Frecuencia objetivo'),
                  rates.containsKey(p.targetFps) ? p.targetFps : 0,
                  rates,
                  (v) => _n.change(
                    (x) => x.copyWith(targetFps: v),
                    keepPreset: true,
                  ),
                  helper: GraphicsPlatform.frameRateChoiceSupported
                      ? (d.refreshRates.isEmpty
                            ? null
                            : '${tr(context, 'Screen supports', 'La pantalla admite')}: ${d.refreshRates.map((r) => r.round()).toSet().join(', ')} Hz')
                      : tr(
                          context,
                          'On this platform the system sets the refresh rate; this still caps decorative animation.',
                          'En esta plataforma el sistema fija la frecuencia; aún limita las animaciones decorativas.',
                        ),
                );
              },
            ),
            select<int>(
              tr(
                context,
                'Decorative animation frequency',
                'Frecuencia de animaciones decorativas',
              ),
              p.decorFps,
              {
                15: '15 fps',
                24: '24 fps',
                30: '30 fps',
                45: '45 fps',
                60: '60 fps',
                0: tr(context, 'Match the display', 'Igual que la pantalla'),
              },
              (v) => _n.change((x) => x.copyWith(decorFps: v)),
              helper: tr(
                context,
                'Living decorations, particles and animated backgrounds. The interface keeps its full frame rate.',
                'Decoraciones vivas, partículas y fondos animados. La interfaz mantiene su frecuencia completa.',
              ),
            ),
            if (GraphicsPlatform.rendererChoiceSupported)
              FutureBuilder<GraphicsDeviceInfo>(
                future: _device,
                builder: (context, snap) => select<RendererMode>(
                  tr(
                    context,
                    'Hardware acceleration',
                    'Aceleración por hardware',
                  ),
                  p.renderer,
                  {for (final r in RendererMode.values) r: r.label},
                  (v) => _n.change(
                    (x) => x.copyWith(renderer: v),
                    keepPreset: true,
                  ),
                  helper:
                      '${p.renderer.description} ${tr(context, 'Applies the next time Prism starts; if a launch fails to draw, Prism switches back to automatic.', 'Se aplica al reiniciar Prism; si no logra dibujar, vuelve a automático.')}'
                      '${snap.data?.renderer == null ? '' : ' (${tr(context, 'now', 'ahora')}: ${snap.data!.renderer})'}',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  tr(
                    context,
                    'Hardware acceleration: always on for this platform (Prism draws with the GPU).',
                    'Aceleración por hardware: siempre activa en esta plataforma.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            TrackerLabel(tr(context, 'Effects', 'Efectos')),
            Text(
              '${tr(context, 'Particle density', 'Densidad de partículas')}: ${(p.particles * 100).round()}%',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: p.particles,
              divisions: 20,
              label: '${(p.particles * 100).round()}%',
              onChanged: (v) => _n.change((x) => x.copyWith(particles: v)),
            ),
            select<Quality>(
              tr(context, 'Animation quality', 'Calidad de animación'),
              p.animation,
              qualities(),
              (v) => _n.change((x) => x.copyWith(animation: v)),
              helper: tr(
                context,
                'Low uses light cross-fade page transitions; Off keeps companions still.',
                'Bajo usa transiciones suaves; Apagado deja quietos a los compañeros.',
              ),
            ),
            select<Quality>(
              tr(
                context,
                'Background animation quality',
                'Calidad de fondos animados',
              ),
              p.backgroundAnimation,
              qualities(),
              (v) => _n.change((x) => x.copyWith(backgroundAnimation: v)),
              helper: tr(
                context,
                'How many decorations move at once and how often ambient effects update. Off keeps them still.',
                'Cuántas decoraciones se mueven a la vez. Apagado las deja quietas.',
              ),
            ),
            select<Quality>(
              tr(context, 'Texture quality', 'Calidad de texturas'),
              p.texture,
              qualities(false),
              (v) => _n.change((x) => x.copyWith(texture: v)),
              helper: tr(
                context,
                'Resolution of backgrounds and decoded pictures, and the image memory budget.',
                'Resolución de fondos e imágenes, y memoria de imágenes.',
              ),
            ),
            select<Quality>(
              tr(context, 'Blur quality', 'Calidad del desenfoque'),
              p.blur,
              qualities(),
              (v) => _n.change((x) => x.copyWith(blur: v)),
              helper: tr(
                context,
                'Glass surfaces. Off uses tinted glass with no live blur.',
                'Superficies de cristal. Apagado usa cristal tintado sin desenfoque.',
              ),
            ),
            select<Quality>(
              tr(context, 'Shadow quality', 'Calidad de sombras'),
              p.shadows,
              qualities(),
              (v) => _n.change((x) => x.copyWith(shadows: v)),
              helper: tr(
                context,
                'Card and decoration shadows and glows.',
                'Sombras y brillos de tarjetas y decoraciones.',
              ),
            ),
            const SizedBox(height: 8),
            TrackerLabel(tr(context, 'Behaviour', 'Comportamiento')),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(context, 'Adaptive graphics', 'Gráficos adaptativos'),
              subtitle: tr(
                context,
                'Lowers decorative detail step by step when frames run late or the device gets hot, and restores it when things are calm.',
                'Reduce el detalle poco a poco si los fotogramas llegan tarde o el dispositivo se calienta, y lo recupera después.',
              ),
              value: p.adaptive || p.preset == GraphicsPreset.adaptive,
              onChanged: (v) => _n.change((x) => x.copyWith(adaptive: v)),
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(context, 'Dynamic resolution', 'Resolución dinámica'),
              subtitle: tr(
                context,
                'Renders cached backgrounds at a lower resolution while quality is reduced.',
                'Dibuja fondos a menor resolución mientras la calidad está reducida.',
              ),
              value: p.dynamicResolution,
              onChanged: (v) =>
                  _n.change((x) => x.copyWith(dynamicResolution: v)),
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(
                context,
                'Battery-saving graphics',
                'Gráficos de ahorro de batería',
              ),
              subtitle: tr(
                context,
                'Uses lighter graphics while the device’s battery saver is on.',
                'Usa gráficos más ligeros con el ahorro de batería del dispositivo.',
              ),
              value: p.batterySaving,
              onChanged: (v) => _n.change(
                (x) => x.copyWith(batterySaving: v),
                keepPreset: true,
              ),
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(
                context,
                'Pause hidden animations',
                'Pausar animaciones ocultas',
              ),
              subtitle: tr(
                context,
                'Stops decorative animation on pages you can’t see (other tabs, pages underneath).',
                'Detiene la animación decorativa en páginas que no se ven.',
              ),
              value: p.suspendOffscreen,
              onChanged: (v) => _n.change(
                (x) => x.copyWith(suspendOffscreen: v),
                keepPreset: true,
              ),
            ),
            PrismSwitchRow(
              padding: EdgeInsets.zero,
              title: tr(
                context,
                'Performance monitor',
                'Monitor de rendimiento',
              ),
              subtitle: tr(
                context,
                'A small draggable readout of real frame timings over the app. Tap it for details.',
                'Un pequeño indicador con tiempos reales de fotogramas. Tócalo para más detalle.',
              ),
              value: p.monitor,
              onChanged: (v) =>
                  _n.change((x) => x.copyWith(monitor: v), keepPreset: true),
            ),
            const SizedBox(height: 16),
            TrackerLabel(tr(context, 'This device', 'Este dispositivo')),
            FutureBuilder<GraphicsDeviceInfo>(
              future: _device,
              builder: (context, snap) {
                final d = snap.data;
                if (d == null) return const SizedBox.shrink();
                final lines = <String>[
                  if (!d.supported)
                    tr(
                      context,
                      'Detailed device information is available on Android.',
                      'La información detallada está disponible en Android.',
                    ),
                  if (d.totalRamMb != null)
                    'RAM: ${(d.totalRamMb! / 1024).toStringAsFixed(1)} GB',
                  if (d.memoryClassMb != null)
                    '${tr(context, 'App memory class', 'Clase de memoria')}: ${d.memoryClassMb} MB',
                  if (d.supported)
                    '${tr(context, 'Low-RAM device', 'Dispositivo con poca RAM')}: ${d.lowRam ? '✓' : '—'}',
                  if (d.refreshRates.isNotEmpty)
                    '${tr(context, 'Refresh rates', 'Frecuencias')}: ${d.refreshRates.map((r) => r.round()).toSet().join(', ')} Hz',
                  if (d.supported)
                    '${tr(context, 'Thermal state', 'Estado térmico')}: ${const ['normal', 'light', 'moderate', 'severe', 'critical', 'emergency', 'shutdown'][d.thermal.clamp(0, 6)]}',
                  if (d.supported)
                    '${tr(context, 'Battery saver', 'Ahorro de batería')}: ${d.powerSave ? 'on' : 'off'}',
                  '${tr(context, 'Decorative effects running', 'Efectos decorativos activos')}: ${DecorClock.instance.activeEffects}',
                ];
                return Text(lines.join('\n'), style: theme.textTheme.bodySmall);
              },
            ),
            const SizedBox(height: 20),
            PrismButton(
              label: tr(
                context,
                'Reset to Adaptive',
                'Restablecer a Adaptativo',
              ),
              icon: Icons.restart_alt,
              onPressed: () => _n.applyPreset(GraphicsPreset.adaptive),
            ),
          ],
        ),
      ),
    );
  }
}
