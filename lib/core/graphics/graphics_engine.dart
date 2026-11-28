import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/graphics/decor_clock.dart';
import 'package:prism_plurality/core/graphics/frame_monitor.dart';
import 'package:prism_plurality/core/graphics/graphics_platform.dart';
import 'package:prism_plurality/core/graphics/graphics_prefs.dart';

/// The rendering budget everything decorative reads from: the person's
/// settings, adjusted by the adaptive engine for how the device is coping.
@immutable
class GraphicsQuality {
  const GraphicsQuality({
    this.level = 1,
    this.particleScale = 1,
    this.decorFps = 30,
    this.ambientFps = 20,
    this.decorAnimates = true,
    this.maxAnimated = 30,
    this.blurScale = 1,
    this.shadowLevel = 3,
    this.textureScale = 1,
    this.animationDetail = 1,
    this.suspendOffscreen = true,
    this.reason = '',
  });

  /// 0.25–1: how much of the full budget is in use (1 = everything).
  final double level;

  /// Multiplier for particle counts (low priority).
  final double particleScale;

  /// Rate for living decorations and animated backgrounds (medium
  /// priority) and for ambient particles and lighting (low priority).
  /// 0 = every display frame.
  final int decorFps, ambientFps;

  /// Background and decorative animation is on at all.
  final bool decorAnimates;

  /// Most moving decorations drawn at once.
  final int maxAnimated;

  /// Multiplier for live blur strength; 0 = no live blur (tinted glass).
  final double blurScale;

  /// 0 none, 1 simple (no blur), 2 soft, 3 full.
  final int shadowLevel;

  /// Resolution multiplier for baked backgrounds and cached layers.
  final double textureScale;

  /// 0–1 detail for interface and companion animations.
  final double animationDetail;
  final bool suspendOffscreen;

  /// Why quality is below the settings (shown in the monitor).
  final String reason;

  bool get liveBlur => blurScale > 0.05;

  /// A blur sigma scaled to the current budget.
  double sigma(double base) => base * blurScale;

  @override
  bool operator ==(Object other) =>
      other is GraphicsQuality &&
      other.level == level &&
      other.particleScale == particleScale &&
      other.decorFps == decorFps &&
      other.ambientFps == ambientFps &&
      other.decorAnimates == decorAnimates &&
      other.maxAnimated == maxAnimated &&
      other.blurScale == blurScale &&
      other.shadowLevel == shadowLevel &&
      other.textureScale == textureScale &&
      other.animationDetail == animationDetail &&
      other.suspendOffscreen == suspendOffscreen &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(
    level,
    particleScale,
    decorFps,
    ambientFps,
    decorAnimates,
    maxAnimated,
    blurScale,
    shadowLevel,
    textureScale,
    animationDetail,
    suspendOffscreen,
    reason,
  );
}

/// Caches elsewhere in the app (decoration glyphs, baked backgrounds)
/// register here so they're released when the system is low on memory.
final graphicsMemoryReleasers = <String, VoidCallback>{};

/// Pure calculation, shared by the engine and tests.
GraphicsQuality computeQuality(
  GraphicsPrefs p, {
  double level = 1,
  String reason = '',
}) {
  final l = level.clamp(0.25, 1.0);
  // Low priority (particles, ambient light) gives way first, then medium
  // (living decorations, animated backgrounds), then blur and shadows.
  final lowF = ((l - 0.4) / 0.6).clamp(0.15, 1.0);
  final medF = ((l - 0.25) / 0.5).clamp(0.3, 1.0);
  final bg = p.backgroundAnimation;
  final decorBase = p.decorFps == 0
      ? (p.targetFps == 0 ? 0 : p.targetFps)
      : p.decorFps;
  int scaleFps(int fps, double f, int floor) {
    if (fps == 0) return f >= 0.999 ? 0 : math.max(floor, (60 * f).round());
    return math.max(floor, (fps * f).round());
  }

  final maxForBg = switch (bg) {
    Quality.off => 0,
    Quality.low => 4,
    Quality.medium => 10,
    Quality.high => 30,
  };
  final ambientCap = switch (bg) {
    Quality.off || Quality.low => 12,
    Quality.medium => 20,
    Quality.high => decorBase,
  };
  final ambientBase = decorBase == 0
      ? ambientCap
      : (ambientCap == 0 ? decorBase : math.min(decorBase, ambientCap));
  var shadow = p.shadows.index;
  if (l < 0.6) shadow -= 1;
  if (l < 0.4) shadow -= 1;
  final blur = l < 0.4 ? 0.0 : p.blur.factor * medF;
  final tex = switch (p.texture) {
    Quality.off => 0.5,
    Quality.low => 0.6,
    Quality.medium => 0.8,
    Quality.high => 1.0,
  };
  return GraphicsQuality(
    level: l,
    particleScale: (p.particles * lowF * (bg == Quality.off ? 0 : 1)).clamp(
      0.0,
      1.0,
    ),
    decorFps: scaleFps(decorBase, medF, 12),
    ambientFps: scaleFps(ambientBase, lowF, 8),
    decorAnimates: bg != Quality.off,
    maxAnimated: (maxForBg * medF).round(),
    blurScale: blur,
    shadowLevel: shadow.clamp(0, 3),
    textureScale: p.dynamicResolution ? tex * l.clamp(0.6, 1.0) : tex,
    animationDetail: p.animation.factor * (l < 0.5 ? 0.7 : 1),
    suspendOffscreen: p.suspendOffscreen,
    reason: reason,
  );
}

/// The adaptive graphics engine. Reads frame timings, thermal state,
/// battery saver and memory, and moves the quality level gradually — a
/// small step at a time, so nothing flickers or jumps.
class GraphicsEngine extends Notifier<GraphicsQuality> {
  Timer? _easeTimer;
  int _ticks = 0;
  bool _listeningSnapshots = false;
  double _level = 1, _target = 1;
  int _badWindows = 0, _goodWindows = 0;
  GraphicsDeviceInfo _device = const GraphicsDeviceInfo();
  bool _watching = false;
  String _reason = '';

  GraphicsDeviceInfo get device => _device;

  @override
  GraphicsQuality build() {
    final prefs = ref.watch(graphicsPrefsProvider);
    ref.onDispose(_stop);
    _start(prefs);
    return _compute(prefs);
  }

  bool _adaptiveOn(GraphicsPrefs p) =>
      p.adaptive || p.preset == GraphicsPreset.adaptive;

  void _start(GraphicsPrefs p) {
    final needsMonitor = _adaptiveOn(p) || p.monitor;
    if (needsMonitor && !_watching) {
      FrameMonitor.instance.watch();
      _watching = true;
    } else if (!needsMonitor && _watching) {
      FrameMonitor.instance.unwatch();
      _watching = false;
    }
    // Evaluation rides on the monitor's samples (which only happen while
    // frames are drawn), so an idle app runs no graphics timers at all.
    if (!_listeningSnapshots) {
      FrameMonitor.instance.snapshot.addListener(_onSample);
      _listeningSnapshots = true;
    }
    if (_device == const GraphicsDeviceInfo()) _refreshDevice(first: true);
    if (!_adaptiveOn(p)) {
      _target = 1;
      _level = 1;
    }
    unawaited(GraphicsPlatform.setFrameRate(p.targetFps));
  }

  void _onSample() {
    _ticks++;
    if (_ticks % 2 == 0) _evaluate();
    // Thermal state and battery saver change slowly: re-read every ~20 s
    // of activity.
    if (_ticks % 20 == 0) _refreshDevice();
  }

  void _stop() {
    _easeTimer?.cancel();
    _easeTimer = null;
    if (_listeningSnapshots) {
      FrameMonitor.instance.snapshot.removeListener(_onSample);
      _listeningSnapshots = false;
    }
    if (_watching) FrameMonitor.instance.unwatch();
    _watching = false;
  }

  /// Re-reads thermal state, battery saver and memory (on app resume).
  Future<void> refreshDevice() => _refreshDevice();

  Future<void> _refreshDevice({bool first = false}) async {
    final d = await GraphicsPlatform.info();
    _device = d;
    if (first && d.lowRam && _adaptiveOn(ref.read(graphicsPrefsProvider))) {
      // Low-RAM devices start lighter and earn their way up.
      _level = _target = 0.7;
    }
    _applyImageCacheBudget();
    _publish();
  }

  /// Image cache sized to the device: decoded images are the biggest use
  /// of graphics memory.
  void _applyImageCacheBudget() {
    final p = ref.read(graphicsPrefsProvider);
    final mem = _device.memoryClassMb;
    var mb = switch (p.texture) {
      Quality.off || Quality.low => 48,
      Quality.medium => 80,
      Quality.high => 120,
    };
    if (_device.lowRam) mb = math.min(mb, 40);
    if (mem != null) mb = math.min(mb, (mem * 0.35).round());
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.maximumSizeBytes = mb.clamp(24, 200) * 1024 * 1024;
      cache.maximumSize = _device.lowRam ? 300 : 800;
    } catch (_) {}
  }

  /// Called on the platform's memory-pressure signal.
  void onMemoryPressure() {
    for (final release in graphicsMemoryReleasers.values) {
      try {
        release();
      } catch (_) {}
    }
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    if (_adaptiveOn(ref.read(graphicsPrefsProvider))) {
      _target = math.max(0.25, _target - 0.25);
      _reason = 'Low memory';
      _ease();
    }
  }

  void _evaluate() {
    final p = ref.read(graphicsPrefsProvider);
    if (!_adaptiveOn(p)) return;
    final s = FrameMonitor.instance.snapshot.value;
    // Hard caps from the device itself.
    double cap = 1;
    var why = '';
    if (_device.thermal >= 3) {
      cap = 0.4;
      why = 'Device is hot';
    } else if (_device.thermal == 2) {
      cap = 0.7;
      why = 'Device is warm';
    }
    if (s.framesRecent >= 20) {
      final overBudget =
          s.droppedRatio > 0.12 ||
          math.max(s.buildMs, s.rasterMs) > s.budgetMs * 1.05;
      final healthy =
          s.droppedRatio < 0.02 &&
          math.max(s.buildMs, s.rasterMs) < s.budgetMs * 0.6;
      if (overBudget) {
        _badWindows++;
        _goodWindows = 0;
      } else if (healthy) {
        _goodWindows++;
        _badWindows = 0;
      } else {
        _badWindows = 0;
        _goodWindows = 0;
      }
      // Sustained trouble (two windows ≈ 4 s) steps down; sustained calm
      // (four windows ≈ 8 s) steps back up.
      if (_badWindows >= 2) {
        _target = math.max(0.25, _target - 0.15);
        _badWindows = 0;
        why = why.isEmpty ? 'Frames running late (${s.bottleneck})' : why;
      } else if (_goodWindows >= 4) {
        _target = math.min(1, _target + 0.1);
        _goodWindows = 0;
      }
    }
    _target = math.min(_target, cap);
    if (why.isNotEmpty) _reason = why;
    if (_target >= 0.999) _reason = '';
    _ease();
  }

  /// Moves the level towards the target in small steps.
  void _ease() {
    if ((_level - _target).abs() < 0.01) {
      _level = _target;
      _publish();
      return;
    }
    _easeTimer ??= Timer.periodic(const Duration(milliseconds: 400), (t) {
      final step = _target < _level ? -0.05 : 0.05;
      _level = (_level + step);
      if ((step < 0 && _level <= _target) || (step > 0 && _level >= _target)) {
        _level = _target;
        t.cancel();
        _easeTimer = null;
      }
      _publish();
    });
  }

  GraphicsQuality _compute(GraphicsPrefs p) {
    var level = _adaptiveOn(p) ? _level : 1.0;
    var reason = _adaptiveOn(p) ? _reason : '';
    if (p.batterySaving && _device.powerSave) {
      level = math.min(level, 0.5);
      reason = 'Battery saver is on';
    }
    return computeQuality(p, level: level, reason: reason);
  }

  void _publish() {
    final q = _compute(ref.read(graphicsPrefsProvider));
    if (q != state) state = q;
  }

  @visibleForTesting
  void setLevelForTest(double l) {
    _level = _target = l;
    _publish();
  }
}

final graphicsEngineProvider =
    NotifierProvider<GraphicsEngine, GraphicsQuality>(GraphicsEngine.new);

/// Keeps the shared decor clock in step with the current quality.
void applyQualityToClock(GraphicsQuality q) {
  DecorClock.instance.configure(
    mediumFps: q.decorAnimates ? q.decorFps : -1,
    lowFps: q.decorAnimates && q.particleScale > 0 ? q.ambientFps : -1,
  );
}

/// Makes the current [GraphicsQuality] available to any widget (including
/// ones that aren't Riverpod consumers, like the shared glass widgets).
class GraphicsScope extends InheritedWidget {
  const GraphicsScope({super.key, required this.quality, required super.child});
  final GraphicsQuality quality;

  static GraphicsQuality of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GraphicsScope>()?.quality ??
      const GraphicsQuality();

  @override
  bool updateShouldNotify(GraphicsScope old) => old.quality != quality;
}

/// Shadows scaled to the graphics budget: full, softer (smaller blur),
/// minimal (tiny blur, cheap to rasterise) or none.
List<BoxShadow>? scaleShadows(List<BoxShadow>? s, GraphicsQuality q) {
  if (s == null || q.shadowLevel >= 3) return s;
  if (q.shadowLevel == 0) return null;
  final f = q.shadowLevel == 2 ? 0.6 : 0.25;
  return [
    for (final b in s)
      BoxShadow(
        color: b.color,
        offset: b.offset * (q.shadowLevel == 2 ? 1 : 0.5),
        blurRadius: b.blurRadius * f,
        spreadRadius: b.spreadRadius * f,
        blurStyle: b.blurStyle,
      ),
  ];
}
