import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prism_plurality/features/seasonal/decor_anchors.dart';
import 'package:prism_plurality/features/seasonal/decor_models.dart';
import 'package:prism_plurality/features/seasonal/decor_painter.dart';
import 'package:prism_plurality/features/seasonal/seasonal_audio.dart';
import 'package:prism_plurality/features/seasonal/seasonal_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';

/// Puts Seasonal Living over the app as an independent layer.
///
///  * It never changes the theme, background, colours or fonts underneath.
///  * Everything but small interactive objects ignores touches, so buttons,
///    text fields, scrolling and navigation work exactly as before.
///  * It sleeps when the app is in the background and draws nothing when
///    Seasonal Living is off.
class SeasonalOverlay extends ConsumerStatefulWidget {
  const SeasonalOverlay({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SeasonalOverlay> createState() => _SeasonalOverlayState();
}

class _SeasonalOverlayState extends ConsumerState<SeasonalOverlay>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  final SeasonalAudio _audio = SeasonalAudio();
  bool _resumed = true;
  String _route = '/';
  bool _lightsOn = true;
  double _burst = 0;
  Timer? _burstTimer;
  final Map<String, ui.Image> _images = {};

  /// Decorations tapped into their other state (lamp off, book open).
  final Set<String> _toggled = {};

  /// The current page's scroll offset, for decorations that move with it.
  double _scroll = 0;
  bool _tracksScroll = false;

  bool _onScroll(ScrollNotification n) {
    if (!_tracksScroll || n.depth != 0 || n.metrics.axis != Axis.vertical) {
      return false;
    }
    final px = n.metrics.pixels;
    if ((px - _scroll).abs() >= 1) setState(() => _scroll = px);
    return false;
  }

  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6);
    widget.router.routerDelegate.addListener(_onRoute);
    _route = widget.router.routerDelegate.currentConfiguration.uri.path;
  }

  void _onRoute() {
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (path == _route) return;
    void apply() {
      if (mounted && path != _route) {
        setState(() {
          _route = path;
          _scroll = 0;
        });
      }
    }

    // The router can notify in the middle of building; never rebuild then.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final r = state == AppLifecycleState.resumed;
    if (r == _resumed) return;
    _resumed = r;
    if (!r) _audio.hush();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router.routerDelegate.removeListener(_onRoute);
    _ticker.dispose();
    _burstTimer?.cancel();
    _audio.dispose();
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }

  void _loadImages(List<DecorItem> items) {
    for (final i in items) {
      final id = i.image;
      if (id == null || _images.containsKey(id) || !_loading.add(id)) continue;
      final bytes = ref.read(socialImageProvider(id));
      if (bytes == null) {
        _loading.remove(id);
        continue;
      }
      ui.decodeImageFromList(bytes, (img) {
        if (!mounted) {
          img.dispose();
          return;
        }
        setState(() => _images[id] = img);
      });
    }
  }

  Widget _tapTarget(DecorItem i, DecorScene scene, Size size) {
    final r = decorItemBounds(i, size, scene);
    if (r.isEmpty || r.width > size.width * 0.5) return const SizedBox();
    return Positioned.fromRect(
      rect: r,
      child: Semantics(
        button: true,
        label: i.glyph ?? i.kind.label,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() {
              if (!_toggled.remove(i.id)) _toggled.add(i.id);
            });
            if (i.sound) _audio.chime(i.sensitivity);
          },
        ),
      ),
    );
  }

  void _shake() {
    _burstTimer?.cancel();
    setState(() => _burst = 1);
    _burstTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _burst = (_burst - 0.04).clamp(0.0, 1.0));
      if (_burst <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(seasonalPrefsProvider);
    final items = ref.watch(seasonalItemsProvider);

    // Sound is separate from decorations: opt-in, and independent of them.
    // A Digital Room can bring its own ambience (only if sound is on).
    final audioId = ref.watch(activeRoomProvider)?.audioId ?? prefs.audioId;
    final wantAudio =
        _resumed &&
        prefs.audioOn &&
        audioId != null &&
        prefs.performance != DecoPerformance.off;
    _audio.apply(on: wantAudio, id: audioId, volume: prefs.audioVolume);

    // The app stays at the same place in the tree whether or not anything
    // is drawn over it, so turning Seasonal Living on or off never rebuilds
    // the app or loses where you were.
    if (prefs.performance == DecoPerformance.off || items.isEmpty) {
      if (_ticker.isActive) {
        _ticker.stop();
        _t.value = 0;
      }
      return Stack(
        textDirection: TextDirection.ltr,
        fit: StackFit.passthrough,
        children: [widget.child],
      );
    }

    final reduced =
        MediaQuery.of(context).disableAnimations || prefs.reducedMotion;
    var layers = prefs.layers.forMode(prefs.performance);
    if (reduced) {
      // Reduced motion: still, quiet decorations only.
      layers = layers.copyWith(
        enabled: {
          for (final l in layers.enabled)
            if (l != DecoLayer.animated && l != DecoLayer.ambient) l,
        },
        particleDensity: 0,
      );
    }
    _loadImages(items);
    _tracksScroll = items.any((i) => i.scroll);
    final phase = ref.watch(currentPhaseProvider);
    final music = ref.watch(decorMusicProvider);

    final needsTicker =
        _resumed &&
        !reduced &&
        (layers.on(DecoLayer.animated) || layers.on(DecoLayer.ambient)) &&
        items.any(
          (i) =>
              i.enabled &&
              (i.layer == DecoLayer.animated ||
                  i.layer == DecoLayer.ambient ||
                  i.moves),
        );
    if (needsTicker && !_ticker.isActive) {
      _ticker.start();
    } else if (!needsTicker && _ticker.isActive) {
      _ticker.stop();
      _t.value = 0;
    }

    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.passthrough,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final mq = MediaQuery.of(context);
              final device = deviceClassFor(box.maxWidth);
              return ValueListenableBuilder<Map<DecoAnchor, Rect>>(
                valueListenable: DecorAnchors.rects,
                builder: (context, anchors, _) {
                  final scene = DecorScene(
                    items: items,
                    layers: layers,
                    device: device,
                    route: _route,
                    uiAnchors: anchors,
                    safe: mq.viewPadding,
                    images: _images,
                    lightsOn: _lightsOn,
                    burst: _burst,
                    phase: phase?.name,
                    music: music,
                    toggled: _toggled,
                    reduced: reduced,
                    scroll: _scroll,
                  );
                  final size = Size(box.maxWidth, box.maxHeight);
                  Widget layer(Set<DecoLayer> which, {required bool moving}) =>
                      RepaintBoundary(
                        child: CustomPaint(
                          size: size,
                          painter: DecorPainter(
                            scene: scene,
                            t: moving ? _t.value : 0,
                            layersToDraw: which,
                            repaint: moving && needsTicker ? _t : null,
                          ),
                        ),
                      );
                  return Stack(
                    textDirection: TextDirection.ltr,
                    children: [
                      // Decoration never takes touches or screen-reader focus.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Stack(
                              textDirection: TextDirection.ltr,
                              fit: StackFit.expand,
                              children: [
                                if (layers.on(DecoLayer.staticDeco))
                                  layer({DecoLayer.staticDeco}, moving: false),
                                if (layers.on(DecoLayer.animated))
                                  layer({DecoLayer.animated}, moving: true),
                                if (layers.on(DecoLayer.ambient))
                                  layer({DecoLayer.ambient}, moving: true),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (layers.on(DecoLayer.interactive) &&
                          mq.viewInsets.bottom == 0)
                        for (final i in items)
                          if (i.enabled &&
                              i.kind == DecoKind.interactive &&
                              i.showsOn(_route) &&
                              !i.tweakFor(device).hidden)
                            _InteractiveObject(
                              key: ValueKey('io-${i.id}'),
                              item: i,
                              scene: scene,
                              size: size,
                              reduced: reduced,
                              onToggleLights: () =>
                                  setState(() => _lightsOn = !_lightsOn),
                              onShake: _shake,
                            ),
                      // Decorations the person made tappable: a lamp
                      // switches, a book opens, a chime rings. Only these
                      // ever take a touch, and only where they're drawn.
                      if (mq.viewInsets.bottom == 0)
                        for (final i in items)
                          if (i.enabled &&
                              i.tap &&
                              i.kind != DecoKind.interactive &&
                              i.showsOn(_route) &&
                              !i.tweakFor(device).hidden)
                            _tapTarget(i, scene, size),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A small thing you can tap: it never blocks anything else, because only
/// its own little area takes touches.
class _InteractiveObject extends StatefulWidget {
  const _InteractiveObject({
    super.key,
    required this.item,
    required this.scene,
    required this.size,
    required this.reduced,
    required this.onToggleLights,
    required this.onShake,
  });
  final DecorItem item;
  final DecorScene scene;
  final Size size;
  final bool reduced;
  final VoidCallback onToggleLights, onShake;

  @override
  State<_InteractiveObject> createState() => _InteractiveObjectState();
}

enum _Behavior { sway, lights, expression, open, bloom, globe }

_Behavior behaviorFor(String glyph) {
  if (glyph == '🎃' || glyph == '🧸' || glyph == '🐰' || glyph == '👻')
    return _Behavior.expression;
  if ('🌸🌷🌼🌻🪷🌺'.contains(glyph)) return _Behavior.bloom;
  if (glyph == '🎁' || glyph == '🪟' || glyph == '🚪' || glyph == '💌')
    return _Behavior.open;
  if (glyph == '🪔' || glyph == '🕯️' || glyph == '🏮' || glyph == '💡')
    return _Behavior.lights;
  if (glyph == '⛄' || glyph == '❄️') return _Behavior.globe;
  return _Behavior.sway;
}

const _faces = {
  '🎃': ['🎃', '😈', '🥳', '😱'],
  '🧸': ['🧸', '🎀', '💖', '✨'],
  '🐰': ['🐰', '🐣', '🥕', '🌷'],
  '👻': ['👻', '😶‍🌫️', '🫥', '👀'],
};

class _InteractiveObjectState extends State<_InteractiveObject> {
  double _turns = 0;
  double _scale = 1;
  int _face = 0;
  String? _bubble;
  Timer? _bubbleTimer;

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  String get _glyph => widget.item.glyph ?? '✨';

  void _tap() {
    final b = behaviorFor(_glyph);
    switch (b) {
      case _Behavior.sway:
        if (widget.reduced) return;
        setState(() => _turns = 0.04);
        Timer(const Duration(milliseconds: 220), () {
          if (mounted) setState(() => _turns = -0.03);
        });
        Timer(const Duration(milliseconds: 440), () {
          if (mounted) setState(() => _turns = 0);
        });
      case _Behavior.lights:
        widget.onToggleLights();
      case _Behavior.expression:
        setState(() => _face = (_face + 1) % (_faces[_glyph]?.length ?? 1));
      case _Behavior.bloom:
        if (widget.reduced) return;
        setState(() => _scale = 1.35);
        Timer(const Duration(milliseconds: 260), () {
          if (mounted) setState(() => _scale = 1);
        });
      case _Behavior.open:
        final v = widget.item.variationId == null
            ? null
            : variationById(widget.item.variationId!);
        final col = v == null ? null : collectionById(v.collectionId);
        final lines = col?.greetings ?? const ['🎉'];
        setState(() => _bubble = lines[DateTime.now().second % lines.length]);
        _bubbleTimer?.cancel();
        _bubbleTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _bubble = null);
        });
      case _Behavior.globe:
        widget.onShake();
        if (!widget.reduced) {
          setState(() => _turns = 0.02);
          Timer(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _turns = -0.02);
          });
          Timer(const Duration(milliseconds: 400), () {
            if (mounted) setState(() => _turns = 0);
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scene = widget.scene;
    final painter = DecorPainter(scene: scene, t: 0, layersToDraw: const {});
    final frame = painter.frameFor(item.anchor, widget.size);
    if (frame == null) return const SizedBox.shrink();
    final tw = item.tweakFor(scene.device);
    final px = (frame.width * item.w * tw.scale).clamp(18.0, 120.0);
    final cx = frame.left + frame.width * (item.x + tw.dx);
    final cy = frame.top + frame.height * (item.y + tw.dy);
    // Keep the touch area comfortably tappable without being large.
    final hit = px < 44 ? 44.0 : px;
    final faces = _faces[_glyph];
    final shown = faces == null ? _glyph : faces[_face % faces.length];
    final behavior = behaviorFor(_glyph);
    final label = switch (behavior) {
      _Behavior.lights => 'Decoration: switch the lights on or off',
      _Behavior.expression => 'Decoration: tap to change its expression',
      _Behavior.open => 'Decoration: tap to open',
      _Behavior.bloom => 'Decoration: tap to bloom',
      _Behavior.globe => 'Decoration: tap to shake the snow',
      _Behavior.sway => 'Decoration: tap to make it sway',
    };
    return Positioned(
      left: cx - hit / 2,
      top: cy - hit / 2,
      width: hit,
      height: hit,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedRotation(
                turns: _turns,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedScale(
                  scale:
                      _scale *
                      (behavior == _Behavior.lights && !scene.lightsOn
                          ? 0.9
                          : 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Opacity(
                    opacity: behavior == _Behavior.lights && !scene.lightsOn
                        ? 0.45
                        : item.opacity,
                    child: Text(
                      shown,
                      style: TextStyle(
                        fontSize: px * 0.9,
                        fontFamilyFallback: const [
                          'NotoColorEmoji',
                          'Apple Color Emoji',
                          'Segoe UI Emoji',
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_bubble != null)
                Positioned(
                  top: hit,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        _bubble!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontSize: 12,
                        ),
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
