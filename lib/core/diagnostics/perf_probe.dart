import 'dart:convert';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'perf_probe_js_stub.dart'
    if (dart.library.js_interop) 'perf_probe_js_web.dart'
    as js;

/// Profiling builds only: `--dart-define=PRISM_PERF=true`. Compiled out of
/// normal builds (every entry point checks this constant first).
const bool kPerfMode = bool.fromEnvironment('PRISM_PERF');

/// Records per-frame timings and exposes a tiny control surface to the page
/// (`window.prismPerf*`) so a browser harness can drive repeatable flows:
/// start/stop frame recording, navigate, start music, count widget builds.
class PerfProbe {
  PerfProbe._();

  static final List<FrameTiming> _frames = [];
  static bool _recording = false;
  static bool _installed = false;
  static final Map<String, String Function(String arg)> _actions = {};

  static void install() {
    if (!kPerfMode || _installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      if (_recording) _frames.addAll(timings);
    });
    register('start', (_) {
      _frames.clear();
      _recording = true;
      return 'ok';
    });
    register('stop', (_) {
      _recording = false;
      return jsonEncode([
        for (final f in _frames)
          {
            'build': f.buildDuration.inMicroseconds / 1000,
            'raster': f.rasterDuration.inMicroseconds / 1000,
            'total': f.totalSpan.inMicroseconds / 1000,
          },
      ]);
    });
    // Widget build tracing: in profile builds, each widget build becomes a
    // browser performance measure named after the widget type.
    register('traceBuilds', (arg) {
      if (kProfileMode) {
        debugProfileBuildsEnabled = arg == 'on';
        debugProfileBuildsEnabledUserWidgets = arg == 'on';
      }
      return kProfileMode ? 'ok' : 'release-build';
    });
    js.exposeDispatcher(_dispatch);
  }

  /// Adds a named action the harness can call as `prismPerf(name, arg)`.
  static void register(String name, String Function(String arg) action) {
    if (!kPerfMode) return;
    _actions[name] = action;
  }

  static String _dispatch(String name, String arg) {
    final action = _actions[name];
    if (action == null) return 'unknown:$name';
    try {
      return action(arg);
    } catch (e) {
      return 'error:$e';
    }
  }
}
