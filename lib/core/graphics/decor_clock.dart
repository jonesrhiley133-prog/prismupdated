import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:prism_plurality/core/graphics/graphics_engine.dart';

/// Rendering priority for decorative motion.
///
/// Critical (touch, typing, scrolling, navigation) and high (transitions,
/// dialogs, interactive components) work is never throttled — it runs on
/// Flutter's own frame scheduling. Decorative motion runs on this shared
/// clock instead, at its own lower rates, and steps aside while the person
/// is interacting.
enum DecorPriority { medium, low }

/// Notices touches, scrolling and typing so decorations can step aside.
class InteractionTracker {
  InteractionTracker._();
  static final InteractionTracker instance = InteractionTracker._();

  int _lastInputUs = 0;
  int _pointersDown = 0;
  bool _installed = false;

  /// Holds for this long after the last input event.
  static const _holdUs = 350000;

  void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) _pointersDown++;
    if (e is PointerUpEvent || e is PointerCancelEvent) {
      _pointersDown = (_pointersDown - 1).clamp(0, 10);
    }
    if (e is PointerDownEvent ||
        e is PointerMoveEvent ||
        e is PointerScrollEvent ||
        e is PointerPanZoomUpdateEvent) {
      _lastInputUs = _now();
    }
  }

  bool _onKey(KeyEvent e) {
    _lastInputUs = _now();
    return false;
  }

  static int _now() => DateTime.now().microsecondsSinceEpoch;

  /// The on-screen keyboard is up (typing on a phone sends no key events).
  bool get keyboardOpen {
    try {
      final v = WidgetsBinding.instance.platformDispatcher.views.first;
      return v.viewInsets.bottom > 0;
    } catch (_) {
      return false;
    }
  }

  /// Someone is touching, scrolling or typing right now.
  bool get busy =>
      _pointersDown > 0 || _now() - _lastInputUs < _holdUs || keyboardOpen;
}

/// A clock channel: seconds since the clock started, updated only at its
/// own rate. Listening to it is what keeps the clock running.
class DecorChannel extends ValueNotifier<double> {
  DecorChannel(this._clock, this.priority) : super(0);
  final DecorClock _clock;
  final DecorPriority priority;
  int _listeners = 0;
  int get listeners => _listeners;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _clock._changed();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listeners > 0) _listeners--;
    _clock._changed();
  }
}

/// One shared, frame-synchronised clock for every decorative animation
/// (living decorations, seasonal particles, banners, ambient effects).
///
/// Instead of each effect running its own ticker at the display's full
/// refresh rate, effects listen to a channel that advances only as often as
/// its priority allows. Between updates no frames are requested at all, so
/// a 120 Hz screen with decorations at 30 fps draws decorations 30 times a
/// second — while scrolling and touch still get every frame.
class DecorClock with WidgetsBindingObserver {
  DecorClock._();
  static final DecorClock instance = DecorClock._();

  late final DecorChannel medium = DecorChannel(this, DecorPriority.medium);
  late final DecorChannel low = DecorChannel(this, DecorPriority.low);

  int _mediumFps = 30;
  int _lowFps = 20;
  bool _resumed = true;
  bool _installed = false;
  bool _yieldToInput = true;
  Timer? _timer;
  bool _frameRequested = false;
  int? _originUs;

  /// Number of effects currently animating on the clock.
  int get activeEffects => medium.listeners + low.listeners;

  void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Rates in frames per second (0 = every display frame). A rate of -1
  /// freezes that priority (decorations hold their current pose).
  void configure({
    required int mediumFps,
    required int lowFps,
    bool yieldToInput = true,
  }) {
    if (mediumFps == _mediumFps &&
        lowFps == _lowFps &&
        yieldToInput == _yieldToInput) {
      return;
    }
    _mediumFps = mediumFps;
    _lowFps = lowFps;
    _yieldToInput = yieldToInput;
    _reschedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Minimised, hidden or behind another app: decorations stop entirely.
    _resumed = state == AppLifecycleState.resumed;
    _reschedule();
  }

  void _changed() => _reschedule();

  bool get _wanted =>
      _resumed &&
      ((medium.listeners > 0 && _mediumFps >= 0) ||
          (low.listeners > 0 && _lowFps >= 0));

  int _intervalUs(int fps) => fps <= 0 ? 0 : (1e6 / fps).round();

  /// While the person is touching, scrolling or typing, decorative motion
  /// slows to leave the frame budget to the interface.
  (int, int) get _effectiveFps {
    if (_yieldToInput && InteractionTracker.instance.busy) {
      final m = _mediumFps == 0 ? 30 : (_mediumFps > 30 ? 30 : _mediumFps);
      return (m, -1); // low priority holds still
    }
    return (_mediumFps, _lowFps);
  }

  /// Engine frame time of the last update per priority (null = never).
  int? _lastMediumTs, _lastLowTs;

  /// Something changed (listeners, rates, lifecycle): draw on the next
  /// frame and work out the schedule from there.
  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!_wanted) return;
    _requestFrame();
  }

  void _requestFrame() {
    if (_frameRequested || !_wanted) return;
    _frameRequested = true;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
    SchedulerBinding.instance.scheduleFrame();
  }

  void _onFrame(Duration ts) {
    _frameRequested = false;
    if (!_wanted) return;
    final now = ts.inMicroseconds;
    _originUs ??= now;
    // Seconds on the engine's frame clock: smooth and vsync-aligned.
    final secs = (now - _originUs!) / 1e6;
    final (mFps, lFps) = _effectiveFps;
    // A little slack so a 30 fps channel on a 60 Hz screen doesn't drop to
    // 20 fps when vsync lands just before the due time.
    bool due(int fps, int? last) =>
        fps >= 0 &&
        (last == null || now - last >= (_intervalUs(fps) * 0.85).round());
    if (medium.listeners > 0 && _mediumFps >= 0 && due(mFps, _lastMediumTs)) {
      _lastMediumTs = now;
      medium.value = secs;
    }
    if (low.listeners > 0 && _lowFps >= 0 && due(lFps, _lastLowTs)) {
      _lastLowTs = now;
      low.value = secs;
    }
    // Sleep until the next channel is due; no frames are requested in
    // between, so a 120 Hz screen isn't kept busy by 30 fps decorations.
    int? wait(int fps, int? last, bool active) {
      if (!active || fps < 0) return null;
      if (fps == 0) return 0;
      final remaining = _intervalUs(fps) - (now - (last ?? now));
      return remaining < 0 ? 0 : remaining;
    }

    final waits = [
      ?wait(mFps, _lastMediumTs, medium.listeners > 0 && _mediumFps >= 0),
      ?wait(lFps, _lastLowTs, low.listeners > 0 && _lowFps >= 0),
    ];
    if (waits.isEmpty) {
      // Low priority is holding still for input; look again shortly.
      _timer = Timer(const Duration(milliseconds: 120), _reschedule);
      return;
    }
    final next = waits.reduce((a, b) => a < b ? a : b);
    // Wake a little early so the frame lands on the due vsync.
    final sleepUs = next - 4000;
    if (sleepUs <= 0) {
      _requestFrame();
    } else {
      _timer = Timer(Duration(microseconds: sleepUs), _requestFrame);
    }
  }

  ValueListenable<double> channel(DecorPriority p) =>
      p == DecorPriority.medium ? medium : low;

  @visibleForTesting
  (int, int) get rates => (_mediumFps, _lowFps);
}

/// Whether decorative animation may run at this point in the tree: false on
/// hidden pages (inactive tabs, routes covered by others) when off-screen
/// suspension is on.
bool decorMayAnimate(BuildContext context, {bool suspendOffscreen = true}) =>
    !suspendOffscreen || TickerMode.of(context);

/// For decorative widgets that animate continuously (companions, habitats,
/// living banners, waving flags, holographic cards...). Instead of an
/// AnimationController ticking at the display's full rate, the widget
/// follows the shared [DecorClock] at its priority's rate, stops on hidden
/// pages, and stops when it leaves the tree.
mixin DecorClockListener<T extends StatefulWidget> on State<T> {
  DecorPriority get decorPriority => DecorPriority.medium;

  /// Seconds on the shared clock (a smooth, ever-increasing timeline).
  void onDecorTick(double seconds);

  bool _wantDecor = false;
  bool _listeningDecor = false;
  bool _decorDepsReady = false;

  /// Turn the animation on or off (respecting visibility automatically).
  void setDecorRunning(bool run) {
    _wantDecor = run;
    _syncDecor();
  }

  double get decorSeconds => DecorClock.instance.channel(decorPriority).value;

  void _onDecor() => onDecorTick(decorSeconds);

  void _syncDecor() {
    // Visibility can only be read once dependencies are available.
    if (!mounted || !_decorDepsReady) return;
    // Hidden pages (inactive tabs, covered routes) stop animating unless
    // off-screen suspension is turned off in Graphics & Performance.
    final visible =
        TickerMode.of(context) ||
        !(context
                .dependOnInheritedWidgetOfExactType<GraphicsScope>()
                ?.quality
                .suspendOffscreen ??
            true);
    final on = _wantDecor && visible;
    final ch = DecorClock.instance.channel(decorPriority) as DecorChannel;
    if (on && !_listeningDecor) {
      ch.addListener(_onDecor);
      _listeningDecor = true;
    } else if (!on && _listeningDecor) {
      ch.removeListener(_onDecor);
      _listeningDecor = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _decorDepsReady = true;
    _syncDecor();
  }

  @override
  void dispose() {
    if (_listeningDecor) {
      (DecorClock.instance.channel(decorPriority) as DecorChannel)
          .removeListener(_onDecor);
      _listeningDecor = false;
    }
    super.dispose();
  }
}

/// A looping 0→1 animation driven by the shared [DecorClock] instead of a
/// full-rate ticker. Drop-in for `AnimationController(..)..repeat()` in
/// decorative widgets: feed it from [DecorClockListener.onDecorTick].
class DecorLoop extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  DecorLoop(this.period);
  Duration period;
  double _value = 0;

  @override
  double get value => _value;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  void tick(double seconds) {
    final p = period.inMicroseconds / 1e6;
    if (p <= 0) return;
    final next = (seconds % p) / p;
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}

  void dispose() {
    clearListeners();
    clearStatusListeners();
  }
}
