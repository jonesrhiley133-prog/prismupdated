import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Records what Prism was doing when it stops responding.
///
/// The UI isolate sends a heartbeat (with a short trail of recent events:
/// pages opened, providers created, slow frames, errors) every half second
/// to a separate watchdog isolate. If heartbeats stop for several seconds
/// the watchdog writes the trail to a file, which Settings → About offers
/// to copy on the next launch. No personal content is recorded: only page
/// paths, component names and timings.
abstract final class FreezeWatchdog {
  static final _trail = ListQueue<String>();
  static const _maxTrail = 120;
  static final _clock = Stopwatch();
  static SendPort? _port;
  static String? _reportPath;
  static Timer? _beat;
  static Duration _lastFrame = Duration.zero;
  static bool _stallLogged = false;
  static bool _foreground = true;
  static bool started = false;
  // ignore: unused_field
  static AppLifecycleListener? _lifecycle;

  static String get _stamp =>
      (_clock.elapsedMilliseconds / 1000).toStringAsFixed(2);

  /// Adds an event to the trail (cheap; safe to call often).
  static void crumb(String event) {
    if (!started) return;
    _trail.add('$_stamp $event');
    while (_trail.length > _maxTrail) {
      _trail.removeFirst();
    }
  }

  static Future<String?> _path() async {
    if (_reportPath != null) return _reportPath;
    if (kIsWeb) return null;
    try {
      _reportPath =
          '${(await getApplicationSupportDirectory()).path}/freeze_report.txt';
    } catch (_) {
      return null;
    }
    return _reportPath;
  }

  /// Starts the watchdog; call once after the first frame.
  static Future<void> start({String appVersion = ''}) async {
    if (started || kIsWeb) return;
    final path = await _path();
    if (path == null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    started = true;
    _clock.start();
    crumb('start $appVersion');
    try {
      final ready = ReceivePort();
      await Isolate.spawn(_watch, [
        ready.sendPort,
        path,
        appVersion,
      ], debugName: 'prism-freeze-watchdog');
      _port = await ready.first as SendPort;
    } catch (_) {
      started = false;
      return;
    }
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        _lastFrame = _clock.elapsed;
        _stallLogged = false;
        final build = t.buildDuration.inMilliseconds;
        final raster = t.rasterDuration.inMilliseconds;
        if (build + raster > 250)
          crumb('slow frame build ${build}ms raster ${raster}ms');
      }
    });
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      crumb('error ${details.exceptionAsString().split('\n').first}');
      previousOnError?.call(details);
    };
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        crumb('lifecycle ${state.name}');
        _foreground = state == AppLifecycleState.resumed;
        if (_foreground) _lastFrame = _clock.elapsed;
        // Backgrounded apps may be frozen by Android; don't report that.
        _port?.send(state == AppLifecycleState.resumed ? 'active' : 'idle');
      },
    );
    var lastTick = _clock.elapsed;
    _beat = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // A late tick means the app's own code (UI thread) was busy.
      final gap = _clock.elapsed - lastTick;
      lastTick = _clock.elapsed;
      if (_foreground && gap > const Duration(milliseconds: 1500)) {
        crumb('UI thread busy ${(gap.inMilliseconds / 1000).toStringAsFixed(1)}s (app code, not drawing)');
      }
      // Frames requested but none finished: the GPU/raster side is stuck
      // even though Dart is still running.
      final waiting =
          SchedulerBinding.instance.hasScheduledFrame ||
          SchedulerBinding.instance.transientCallbackCount > 0;
      if (waiting &&
          _foreground &&
          !_stallLogged &&
          _clock.elapsed - _lastFrame > const Duration(seconds: 4)) {
        _stallLogged = true;
        crumb(
          'frames stalled ${(_clock.elapsed - _lastFrame).inSeconds}s',
        );
        _port?.send(_trail.join('\n'));
        _port?.send('stall');
      }
      _port?.send(_trail.join('\n'));
    });
  }

  static void stop() => _beat?.cancel();

  /// The saved report from a previous freeze, if any.
  static Future<String?> lastReport() async {
    final path = await _path();
    if (path == null) return null;
    try {
      final f = File(path);
      return await f.exists() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearReport() async {
    final path = await _path();
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

/// Watchdog isolate: writes the trail when heartbeats stop.
void _watch(List<Object?> args) {
  final back = args[0]! as SendPort;
  final path = args[1]! as String;
  final version = args[2]! as String;
  final inbox = ReceivePort();
  back.send(inbox.sendPort);
  var lastBeat = DateTime.now();
  var trail = '';
  DateTime? stuckSince;
  var idle = false;
  var lastTick = DateTime.now();
  inbox.listen((msg) {
    final now = DateTime.now();
    if (msg == 'stall') {
      try {
        File(path).writeAsStringSync(
          'Prism stopped drawing the screen\n'
          'Version: $version\n'
          'When: ${now.toIso8601String()}\n'
          'No frames for over 4s. If a "UI thread busy" line is just above, app code was blocking; otherwise drawing (GPU) was stuck.\n'
          '\nLast events (seconds since start):\n$trail\n',
        );
      } catch (_) {}
      lastBeat = now;
      return;
    }
    if (msg == 'idle' || msg == 'active') {
      idle = msg == 'idle';
      lastBeat = now;
      return;
    }
    if (msg is String) trail = msg;
    if (stuckSince != null) {
      // Recovered: note how long it was stuck.
      try {
        File(path).writeAsStringSync(
          '\nRecovered after ${now.difference(stuckSince!).inSeconds}s.\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      stuckSince = null;
    }
    lastBeat = now;
  });
  Timer.periodic(const Duration(seconds: 1), (_) {
    final now = DateTime.now();
    // If this isolate's own timer ran very late, the whole process was
    // paused (e.g. by the OS), not just the UI thread.
    if (now.difference(lastTick) > const Duration(seconds: 3)) lastBeat = now;
    lastTick = now;
    if (idle) return;
    final silent = now.difference(lastBeat);
    if (silent < const Duration(seconds: 5)) return;
    stuckSince ??= lastBeat;
    // Rewrite every few seconds so the report shows the full duration even
    // if Android kills the app.
    if (silent.inSeconds % 3 != 2 && silent.inSeconds != 5) return;
    try {
      File(path).writeAsStringSync(
        'Prism stopped responding\n'
        'Version: $version\n'
        'When: ${lastBeat.toIso8601String()}\n'
        'App blocked for at least ${silent.inSeconds}s (Dart UI thread).\n'
        '\nLast events (seconds since start):\n$trail\n',
      );
    } catch (_) {}
  });
}

/// Adds provider creations and failures to the freeze trail (names only).
final class FreezeTrailObserver extends ProviderObserver {
  const FreezeTrailObserver();

  static String _name(ProviderObserverContext c) =>
      c.provider.name ?? c.provider.runtimeType.toString();

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (FreezeWatchdog.started) FreezeWatchdog.crumb('+ ${_name(context)}');
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (FreezeWatchdog.started) {
      FreezeWatchdog.crumb('! ${_name(context)} failed: ${error.runtimeType}');
    }
  }
}
