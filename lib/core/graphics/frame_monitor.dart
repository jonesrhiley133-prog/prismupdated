import 'dart:async';
import 'dart:io' show File, Platform, ProcessInfo;
import 'dart:ui' as ui;
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// One reading of how rendering is going. Every number is measured from
/// the engine's real frame timings or the operating system — nothing is
/// estimated. Values that can't be measured on a platform are null.
@immutable
class PerfSnapshot {
  const PerfSnapshot({
    this.fps = 0,
    this.averageFps = 0,
    this.buildMs = 0,
    this.rasterMs = 0,
    this.worstMs = 0,
    this.budgetMs = 16.7,
    this.droppedRecent = 0,
    this.droppedTotal = 0,
    this.framesRecent = 0,
    this.cpuPercent,
    this.rssMb,
    this.imageCacheMb = 0,
    this.animations = 0,
    this.refreshRate = 60,
  });

  /// Frames drawn in the last second (Flutter only draws when something
  /// changes, so an idle screen reads low without being slow).
  final double fps;

  /// Average frame rate over the recent busy period.
  final double averageFps;

  /// Average UI-thread (build, layout, paint) and raster (GPU) time of
  /// recent frames, in ms.
  final double buildMs, rasterMs;

  /// Slowest recent frame (build + raster), in ms.
  final double worstMs;

  /// Time available per frame at the display's refresh rate.
  final double budgetMs;

  /// Frames that missed their vsync in the last ~4 s, and since launch.
  final int droppedRecent, droppedTotal;
  final int framesRecent;

  /// Process CPU use across all cores (Android and Linux only).
  final double? cpuPercent;

  /// Resident memory of the app process.
  final double? rssMb;
  final double imageCacheMb;

  /// Animations running right now (Flutter's active tickers).
  final int animations;
  final double refreshRate;

  double get droppedRatio =>
      framesRecent == 0 ? 0 : droppedRecent / framesRecent;

  /// Where time is going when frames are late.
  String get bottleneck {
    if (framesRecent < 10) return 'Idle';
    final lateRaster = rasterMs > budgetMs * 0.85;
    final lateBuild = buildMs > budgetMs * 0.85;
    if (lateRaster && rasterMs >= buildMs) return 'GPU raster';
    if (lateBuild) return 'UI thread (build, layout, paint)';
    if (droppedRatio > 0.05) return 'Occasional long frames';
    return 'None';
  }
}

/// Collects real frame timings from the engine (FrameTiming) and samples
/// CPU and memory while someone is watching (the monitor, the settings
/// page or the adaptive engine).
class FrameMonitor {
  FrameMonitor._();
  static final FrameMonitor instance = FrameMonitor._();

  final ValueNotifier<PerfSnapshot> snapshot = ValueNotifier(
    const PerfSnapshot(),
  );

  final List<FrameTiming> _recent = [];
  int _lastArrivalUs = 0;
  final List<(int, int)> _fpsHistory = []; // (epoch ms, frames that second)
  int _droppedTotal = 0;
  int _watchers = 0;
  Timer? _timer;
  bool _attached = false;
  int? _lastCpuTicks;
  DateTime? _lastCpuAt;
  double? _cpu;

  /// Starts collecting (counted; call [unwatch] when done).
  void watch() {
    _watchers++;
    if (!_attached) {
      _attached = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
    // The 1 s sampling timer only runs while frames are being drawn (it is
    // started by the first frame timings and stops when the app is idle).
  }

  void unwatch() {
    if (_watchers > 0) _watchers--;
    if (_watchers == 0) {
      _timer?.cancel();
      _timer = null;
      if (_attached) {
        SchedulerBinding.instance.removeTimingsCallback(_onTimings);
        _attached = false;
      }
      _recent.clear();
    }
  }

  bool get watching => _watchers > 0;

  double get _refreshRate {
    try {
      final r = ui.PlatformDispatcher.instance.views.first.display.refreshRate;
      return r > 1 ? r : 60;
    } catch (_) {
      return 60;
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    final budget = Duration(microseconds: (1e6 / _refreshRate).round());
    _lastArrivalUs = DateTime.now().microsecondsSinceEpoch;
    if (_watchers > 0) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    for (final t in timings) {
      _recent.add(t);
      if (t.buildDuration > budget || t.rasterDuration > budget) {
        _droppedTotal++;
      }
    }
    // Keep about 4 seconds at 120 Hz.
    if (_recent.length > 480) _recent.removeRange(0, _recent.length - 480);
  }

  void _tick() {
    final now = DateTime.now();
    final rate = _refreshRate;
    final budgetUs = 1e6 / rate;
    // Frames whose vsync fell in the last second / four seconds, counted
    // back from the newest frame (engine clock). If nothing has arrived for
    // a while the screen is idle.
    final nowUs = now.microsecondsSinceEpoch;
    final idleUs = nowUs - _lastArrivalUs;
    if (idleUs > 6000000) {
      // Idle: publish a final idle reading and stop sampling until the
      // next frame arrives.
      _timer?.cancel();
      _timer = null;
    }
    final newest = _recent.isEmpty
        ? 0
        : _recent.last.timestampInMicroseconds(FramePhase.vsyncStart);
    int vs(FrameTiming t) => t.timestampInMicroseconds(FramePhase.vsyncStart);
    final recent = idleUs > 4000000
        ? <FrameTiming>[]
        : [
            for (final t in _recent)
              if (vs(t) >= newest - 4000000 + idleUs) t,
          ];
    final lastSecondCount = idleUs > 1200000
        ? 0
        : recent.where((t) => vs(t) >= newest - 1000000 + idleUs).length;
    final fps = lastSecondCount.toDouble();
    _fpsHistory.add((now.millisecondsSinceEpoch, lastSecondCount));
    if (_fpsHistory.length > 30) _fpsHistory.removeAt(0);
    final busy = [
      for (final (_, n) in _fpsHistory)
        if (n >= 5) n,
    ];
    final avg = busy.isEmpty ? 0.0 : busy.reduce((a, b) => a + b) / busy.length;
    double avgMs(Duration Function(FrameTiming) f) => recent.isEmpty
        ? 0
        : recent.map((t) => f(t).inMicroseconds).reduce((a, b) => a + b) /
              recent.length /
              1000;
    final worst = recent.isEmpty
        ? 0.0
        : recent
                  .map(
                    (t) =>
                        t.buildDuration.inMicroseconds +
                        t.rasterDuration.inMicroseconds,
                  )
                  .reduce((a, b) => a > b ? a : b) /
              1000;
    final dropped = recent
        .where(
          (t) =>
              t.buildDuration.inMicroseconds > budgetUs ||
              t.rasterDuration.inMicroseconds > budgetUs,
        )
        .length;
    _sampleCpu(now);
    double? rss;
    if (!kIsWeb) {
      try {
        rss = ProcessInfo.currentRss / (1024 * 1024);
      } catch (_) {}
    }
    final cache = PaintingBindingHelper.imageCacheBytes() / (1024 * 1024);
    snapshot.value = PerfSnapshot(
      fps: fps,
      averageFps: avg,
      buildMs: avgMs((t) => t.buildDuration),
      rasterMs: avgMs((t) => t.rasterDuration),
      worstMs: worst,
      budgetMs: budgetUs / 1000,
      droppedRecent: dropped,
      droppedTotal: _droppedTotal,
      framesRecent: recent.length,
      cpuPercent: _cpu,
      rssMb: rss,
      imageCacheMb: cache,
      animations: SchedulerBinding.instance.transientCallbackCount,
      refreshRate: rate,
    );
  }

  /// Process CPU time from /proc (Linux kernels: Android, Linux desktop).
  void _sampleCpu(DateTime now) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isLinux)) return;
    try {
      final stat = File('/proc/self/stat').readAsStringSync();
      // Fields after the "(comm)" part; utime and stime are 14th and 15th.
      final rest = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
      final ticks = int.parse(rest[11]) + int.parse(rest[12]);
      if (_lastCpuTicks != null && _lastCpuAt != null) {
        final secs = now.difference(_lastCpuAt!).inMicroseconds / 1e6;
        if (secs > 0) {
          const clkTck = 100; // USER_HZ on Android and Linux
          final used = (ticks - _lastCpuTicks!) / clkTck;
          _cpu = (used / secs / Platform.numberOfProcessors * 100).clamp(
            0.0,
            100.0,
          );
        }
      }
      _lastCpuTicks = ticks;
      _lastCpuAt = now;
    } catch (_) {
      _cpu = null;
    }
  }
}

/// Keeps painting imports out of the monitor's public surface.
abstract final class PaintingBindingHelper {
  static int imageCacheBytes() {
    try {
      return PaintingBinding.instance.imageCache.currentSizeBytes;
    } catch (_) {
      return 0;
    }
  }
}
