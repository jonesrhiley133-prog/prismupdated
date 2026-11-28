import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/graphics/decor_clock.dart';
import 'package:prism_plurality/core/graphics/frame_monitor.dart';
import 'package:prism_plurality/core/graphics/graphics_engine.dart';
import 'package:prism_plurality/core/graphics/graphics_platform.dart';
import 'package:prism_plurality/core/graphics/graphics_prefs.dart';

/// Hosts the graphics engine at the root of the app: input tracking for
/// rendering priority, the shared decor clock, memory-pressure handling and
/// the optional performance monitor overlay.
class GraphicsHost extends ConsumerStatefulWidget {
  const GraphicsHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GraphicsHost> createState() => _GraphicsHostState();
}

class _GraphicsHostState extends ConsumerState<GraphicsHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InteractionTracker.instance.install();
    DecorClock.instance.install();
    // The first frame made it to the screen: keep the chosen renderer.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => GraphicsPlatform.markRendered(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(graphicsEngineProvider.notifier).refreshDevice();
    }
  }

  @override
  void didHaveMemoryPressure() {
    ref.read(graphicsEngineProvider.notifier).onMemoryPressure();
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(graphicsEngineProvider);
    applyQualityToClock(q);
    final monitor = ref.watch(graphicsPrefsProvider.select((p) => p.monitor));
    final child = GraphicsScope(quality: q, child: widget.child);
    if (!monitor) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.passthrough,
      children: [child, const _MonitorOverlay()],
    );
  }
}

/// A small, draggable readout of live rendering numbers.
class _MonitorOverlay extends StatefulWidget {
  const _MonitorOverlay();
  @override
  State<_MonitorOverlay> createState() => _MonitorOverlayState();
}

class _MonitorOverlayState extends State<_MonitorOverlay> {
  Offset _pos = const Offset(8, 80);
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    FrameMonitor.instance.watch();
  }

  @override
  void dispose() {
    FrameMonitor.instance.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: _pos.dx.clamp(0, size.width - 120),
      top: _pos.dy.clamp(0, size.height - 60),
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _pos += d.delta),
        onTap: () => setState(() => _expanded = !_expanded),
        child: RepaintBoundary(
          child: Material(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.3,
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final q = ref.watch(graphicsEngineProvider);
                    return ValueListenableBuilder<PerfSnapshot>(
                      valueListenable: FrameMonitor.instance.snapshot,
                      builder: (context, s, _) =>
                          PerfReadout(s: s, q: q, expanded: _expanded),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The numbers, shared by the overlay and the settings page.
class PerfReadout extends StatelessWidget {
  const PerfReadout({
    super.key,
    required this.s,
    required this.q,
    this.expanded = true,
  });
  final PerfSnapshot s;
  final GraphicsQuality q;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    String f(double v, [int d = 1]) => v.toStringAsFixed(d);
    final lines = <String>[
      '${f(s.fps, 0)} fps · ${f(s.buildMs)}/${f(s.rasterMs)} ms',
      if (expanded) ...[
        'avg ${f(s.averageFps, 0)} fps @ ${f(s.refreshRate, 0)} Hz',
        'frame budget ${f(s.budgetMs)} ms · worst ${f(s.worstMs)} ms',
        'dropped ${s.droppedRecent}/${s.framesRecent} (total ${s.droppedTotal})',
        'CPU ${s.cpuPercent == null ? 'n/a' : '${f(s.cpuPercent!, 0)}%'}'
            ' · GPU usage n/a',
        'memory ${s.rssMb == null ? 'n/a' : '${f(s.rssMb!, 0)} MB'}'
            ' · images ${f(s.imageCacheMb, 0)} MB',
        'animations ${s.animations} · decor effects ${DecorClock.instance.activeEffects}',
        'quality ${(q.level * 100).round()}% · decor ${q.decorFps == 0 ? 'max' : q.decorFps} fps',
        'bottleneck ${s.bottleneck}',
        if (q.reason.isNotEmpty) q.reason,
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final l in lines) Text(l)],
    );
  }
}

/// The lightest page transition: a short cross-fade (opacity only, which
/// the GPU composites without re-rendering the page). Used at low animation
/// quality on every platform.
class LightFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const LightFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}
