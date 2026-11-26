import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:prism_plurality/features/scrapbook/scrap_models.dart';
import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A video on a scrapbook page.
///
/// Every instance owns its own [VideoPlayerController], created only while
/// the element is actually visible and released as soon as it scrolls or
/// pages away. Nothing is shared between elements: the media id, loop,
/// autoplay, volume and thumbnail all come from the element's own options,
/// so adding, editing or deleting one video can never touch another.
class ScrapVideoView extends ConsumerStatefulWidget {
  const ScrapVideoView({
    super.key,
    required this.element,
    this.fit = BoxFit.cover,
  });
  final ScrapElement element;
  final BoxFit fit;

  @override
  ConsumerState<ScrapVideoView> createState() => _ScrapVideoViewState();
}

class _ScrapVideoViewState extends ConsumerState<ScrapVideoView>
    with WidgetsBindingObserver {
  VideoPlayerController? _c;
  String? _loadedPath;
  bool _visible = false;
  bool _failed = false;
  bool _disposed = false;
  int _gen = 0;

  ScrapElement get _e => widget.element;
  bool get _loop => _e.opt('loop', false);
  bool get _auto => _e.opt('auto', false);
  double get _vol => _e.opt('vol', 1.0).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background: pause everything so nothing keeps decoding.
    if (state != AppLifecycleState.resumed) _c?.pause();
  }

  @override
  void didUpdateWidget(ScrapVideoView old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c != null && c.value.isInitialized) {
      c.setLooping(_loop);
      c.setVolume(_vol);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  void _release() {
    _gen++;
    final c = _c;
    _c = null;
    _loadedPath = null;
    c?.dispose();
  }

  Future<void> _load(String path) async {
    if (_loadedPath == path && _c != null) return;
    _release();
    final gen = _gen;
    _loadedPath = path;
    final c = VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _c = c;
    try {
      await c.initialize();
      if (_disposed || gen != _gen) {
        await c.dispose();
        return;
      }
      await c.setLooping(_loop);
      await c.setVolume(_vol);
      if (_auto && _visible) await c.play();
      if (mounted) setState(() => _failed = false);
    } catch (_) {
      if (gen == _gen) {
        _c = null;
        _loadedPath = null;
        await c.dispose();
        if (mounted) setState(() => _failed = true);
      }
    }
  }

  void _onVisible(VisibilityInfo info) {
    if (_disposed) return;
    final vis = info.visibleFraction > 0.25;
    if (vis == _visible) return;
    _visible = vis;
    final path = ref.read(socialVideoPathProvider(_e.media ?? ''));
    if (vis) {
      if (path != null) _load(path);
    } else {
      // Offscreen: pause and free the decoder.
      _c?.pause();
      _release();
      if (mounted) setState(() {});
    }
  }

  void _toggle() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final id = _e.media;
    final path = id == null ? null : ref.watch(socialVideoPathProvider(id));
    final thumb = _e.opts['thumb'] as String?;
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final started =
        ready && (c.value.isPlaying || c.value.position > Duration.zero);

    Widget body;
    if (id == null || path == null) {
      body = ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              tr(
                context,
                'Video on another device',
                'Vídeo en otro dispositivo',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (!started && thumb != null)
            PrismMediaView(id: thumb, fit: widget.fit),
          if (ready)
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          if (_failed)
            const Center(
              child: Icon(Icons.error_outline, color: Colors.white54),
            )
          else if (!ready && thumb == null)
            const Center(
              child: Icon(Icons.movie_outlined, color: Colors.white54),
            ),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: (ready && c.value.isPlaying) ? 0 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: prismRound(context),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return VisibilityDetector(
      // Unique per element: two videos never share a detector.
      key: ValueKey('scrapvid-${_e.id}'),
      onVisibilityChanged: _onVisible,
      child: body,
    );
  }
}
