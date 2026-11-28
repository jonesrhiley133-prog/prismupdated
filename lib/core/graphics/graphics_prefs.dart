import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Graphics & Performance settings. Stored per device (never synced: a
/// phone and a tablet need different settings), applied immediately.
enum GraphicsPreset {
  ultra('Ultra', 'Maximum fidelity on capable devices.'),
  high('High', 'Rich effects with optimised rendering.'),
  balanced('Balanced', 'Quality and responsiveness together.'),
  performance('Performance', 'Lighter workload, same overall look.'),
  lightweight('Ultra Lightweight', 'Minimal resources for older devices.'),
  adaptive('Adaptive', 'Adjusts quality to how the device is coping.'),
  custom('Custom', 'Your own combination.');

  const GraphicsPreset(this.label, this.description);
  final String label, description;
}

/// Four quality steps used by most individual controls.
enum Quality {
  off('Off'),
  low('Low'),
  medium('Medium'),
  high('High');

  const Quality(this.label);
  final String label;
  double get factor => switch (this) {
    off => 0,
    low => 0.4,
    medium => 0.7,
    high => 1,
  };
}

/// How Flutter draws on Android. Takes effect on the next launch.
enum RendererMode {
  auto(
    'Automatic (recommended)',
    'Modern GPU renderer with built-in fallbacks.',
  ),
  compatibility(
    'Compatibility',
    'Older OpenGL renderer, for GPUs with driver problems.',
  ),
  software('Software', 'Draws on the CPU only. Slow; for broken GPUs.');

  const RendererMode(this.label, this.description);
  final String label, description;
}

class GraphicsPrefs {
  const GraphicsPrefs({
    this.preset = GraphicsPreset.adaptive,
    this.targetFps = 0,
    this.renderer = RendererMode.auto,
    this.particles = 1,
    this.animation = Quality.high,
    this.backgroundAnimation = Quality.high,
    this.texture = Quality.high,
    this.blur = Quality.high,
    this.shadows = Quality.high,
    this.decorFps = 30,
    this.dynamicResolution = true,
    this.adaptive = true,
    this.batterySaving = true,
    this.suspendOffscreen = true,
    this.monitor = false,
  });

  final GraphicsPreset preset;

  /// Display refresh rate to ask for (0 = the device's own choice).
  final int targetFps;
  final RendererMode renderer;

  /// 0–1 multiplier for particle counts.
  final double particles;

  /// Interface and companion animation detail.
  final Quality animation;

  /// Animated backgrounds and living decorations.
  final Quality backgroundAnimation;

  /// Resolution of baked backgrounds and cached decoration layers.
  final Quality texture;
  final Quality blur;
  final Quality shadows;

  /// Frames per second for decorative movement (0 = match the display).
  /// Independent of interface responsiveness.
  final int decorFps;

  /// Render cached effects at a lower resolution when the device struggles.
  final bool dynamicResolution;

  /// Let the adaptive engine lower (and later restore) quality on its own.
  final bool adaptive;

  /// Use lighter graphics while the device's battery saver is on.
  final bool batterySaving;

  /// Stop decorative animations that can't be seen.
  final bool suspendOffscreen;

  /// Show the performance monitor overlay.
  final bool monitor;

  static GraphicsPrefs forPreset(GraphicsPreset p, {GraphicsPrefs? keep}) {
    final base = switch (p) {
      GraphicsPreset.ultra => const GraphicsPrefs(
        preset: GraphicsPreset.ultra,
        particles: 1,
        animation: Quality.high,
        backgroundAnimation: Quality.high,
        texture: Quality.high,
        blur: Quality.high,
        shadows: Quality.high,
        decorFps: 0,
        dynamicResolution: false,
        adaptive: false,
      ),
      GraphicsPreset.high => const GraphicsPrefs(
        preset: GraphicsPreset.high,
        particles: 0.9,
        animation: Quality.high,
        backgroundAnimation: Quality.high,
        texture: Quality.high,
        blur: Quality.high,
        shadows: Quality.medium,
        decorFps: 60,
        dynamicResolution: false,
        adaptive: false,
      ),
      GraphicsPreset.balanced => const GraphicsPrefs(
        preset: GraphicsPreset.balanced,
        particles: 0.7,
        animation: Quality.high,
        backgroundAnimation: Quality.medium,
        texture: Quality.medium,
        blur: Quality.medium,
        shadows: Quality.medium,
        decorFps: 30,
        adaptive: false,
      ),
      GraphicsPreset.performance => const GraphicsPrefs(
        preset: GraphicsPreset.performance,
        particles: 0.45,
        animation: Quality.medium,
        backgroundAnimation: Quality.low,
        texture: Quality.medium,
        blur: Quality.low,
        shadows: Quality.low,
        decorFps: 24,
        adaptive: false,
      ),
      GraphicsPreset.lightweight => const GraphicsPrefs(
        preset: GraphicsPreset.lightweight,
        particles: 0.2,
        animation: Quality.low,
        backgroundAnimation: Quality.low,
        texture: Quality.low,
        blur: Quality.off,
        shadows: Quality.off,
        decorFps: 15,
        adaptive: false,
      ),
      GraphicsPreset.adaptive || GraphicsPreset.custom => const GraphicsPrefs(),
    };
    final k = keep;
    if (k == null) return base;
    // Device-level choices survive a preset change.
    return base.copyWith(
      targetFps: k.targetFps,
      renderer: k.renderer,
      batterySaving: k.batterySaving,
      suspendOffscreen: k.suspendOffscreen,
      monitor: k.monitor,
    );
  }

  GraphicsPrefs copyWith({
    GraphicsPreset? preset,
    int? targetFps,
    RendererMode? renderer,
    double? particles,
    Quality? animation,
    Quality? backgroundAnimation,
    Quality? texture,
    Quality? blur,
    Quality? shadows,
    int? decorFps,
    bool? dynamicResolution,
    bool? adaptive,
    bool? batterySaving,
    bool? suspendOffscreen,
    bool? monitor,
  }) => GraphicsPrefs(
    preset: preset ?? this.preset,
    targetFps: targetFps ?? this.targetFps,
    renderer: renderer ?? this.renderer,
    particles: particles ?? this.particles,
    animation: animation ?? this.animation,
    backgroundAnimation: backgroundAnimation ?? this.backgroundAnimation,
    texture: texture ?? this.texture,
    blur: blur ?? this.blur,
    shadows: shadows ?? this.shadows,
    decorFps: decorFps ?? this.decorFps,
    dynamicResolution: dynamicResolution ?? this.dynamicResolution,
    adaptive: adaptive ?? this.adaptive,
    batterySaving: batterySaving ?? this.batterySaving,
    suspendOffscreen: suspendOffscreen ?? this.suspendOffscreen,
    monitor: monitor ?? this.monitor,
  );

  Map<String, Object?> toJson() => {
    'preset': preset.name,
    'fps': targetFps,
    'renderer': renderer.name,
    'particles': particles,
    'animation': animation.name,
    'bgAnimation': backgroundAnimation.name,
    'texture': texture.name,
    'blur': blur.name,
    'shadows': shadows.name,
    'decorFps': decorFps,
    'dynRes': dynamicResolution,
    'adaptive': adaptive,
    'battery': batterySaving,
    'offscreen': suspendOffscreen,
    'monitor': monitor,
  };

  static GraphicsPrefs fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    T pick<T extends Enum>(List<T> values, Object? v, T d) =>
        values.where((x) => x.name == v).firstOrNull ?? d;
    const d = GraphicsPrefs();
    return GraphicsPrefs(
      preset: pick(GraphicsPreset.values, j['preset'], d.preset),
      targetFps: const [0, 30, 60, 90, 120].contains(j['fps'])
          ? j['fps'] as int
          : 0,
      renderer: pick(RendererMode.values, j['renderer'], d.renderer),
      particles: ((j['particles'] as num?)?.toDouble() ?? d.particles).clamp(
        0.0,
        1.0,
      ),
      animation: pick(Quality.values, j['animation'], d.animation),
      backgroundAnimation: pick(
        Quality.values,
        j['bgAnimation'],
        d.backgroundAnimation,
      ),
      texture: pick(Quality.values, j['texture'], d.texture),
      blur: pick(Quality.values, j['blur'], d.blur),
      shadows: pick(Quality.values, j['shadows'], d.shadows),
      decorFps: const [0, 15, 24, 30, 45, 60].contains(j['decorFps'])
          ? j['decorFps'] as int
          : d.decorFps,
      dynamicResolution: j['dynRes'] is bool
          ? j['dynRes'] as bool
          : d.dynamicResolution,
      adaptive: j['adaptive'] is bool ? j['adaptive'] as bool : d.adaptive,
      batterySaving: j['battery'] is bool
          ? j['battery'] as bool
          : d.batterySaving,
      suspendOffscreen: j['offscreen'] is bool
          ? j['offscreen'] as bool
          : d.suspendOffscreen,
      monitor: j['monitor'] is bool ? j['monitor'] as bool : d.monitor,
    );
  }
}

const graphicsPrefsKey = 'prism.graphics.v1';

/// Read by Android before Flutter starts (see MainActivity), so it lives in
/// its own key: 'auto' | 'compatibility' | 'software'.
const graphicsRendererKey = 'prism.graphics.renderer';

class GraphicsPrefsNotifier extends Notifier<GraphicsPrefs> {
  @override
  GraphicsPrefs build() {
    _load();
    return const GraphicsPrefs();
  }

  bool _loaded = false;

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(graphicsPrefsKey);
      if (raw != null && !_loaded) {
        state = GraphicsPrefs.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save(GraphicsPrefs next) async {
    _loaded = true;
    state = next;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(graphicsPrefsKey, jsonEncode(next.toJson()));
      await sp.setString(graphicsRendererKey, next.renderer.name);
    } catch (_) {
      // Kept for this session.
    }
  }

  Future<void> applyPreset(GraphicsPreset p) =>
      _save(GraphicsPrefs.forPreset(p, keep: state));

  /// Any individual change makes the settings "Custom" (except device-level
  /// choices that every preset keeps).
  Future<void> change(
    GraphicsPrefs Function(GraphicsPrefs) f, {
    bool keepPreset = false,
  }) {
    final next = f(state);
    return _save(
      keepPreset ? next : next.copyWith(preset: GraphicsPreset.custom),
    );
  }

  /// Test hook.
  void setForTest(GraphicsPrefs p) {
    _loaded = true;
    state = p;
  }
}

final graphicsPrefsProvider =
    NotifierProvider<GraphicsPrefsNotifier, GraphicsPrefs>(
      GraphicsPrefsNotifier.new,
    );
