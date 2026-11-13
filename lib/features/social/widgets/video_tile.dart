import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:prism_plurality/features/social/services/social_media.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Plays a video stored on this device (tap to play/pause). Videos added on
/// another device show a note instead, since videos do not sync.
class VideoTile extends ConsumerStatefulWidget {
  const VideoTile({super.key, required this.id, this.autoplay = false, this.loop = false, this.onReady, this.fill = false});

  final String id;
  final bool autoplay;
  final bool loop;
  final bool fill;

  /// Called with the duration once the video is loaded (used by stories).
  final ValueChanged<Duration>? onReady;

  @override
  ConsumerState<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends ConsumerState<VideoTile> {
  VideoPlayerController? _c;
  String? _path;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _load(String path) async {
    if (_path == path) return;
    _path = path;
    final old = _c;
    final c = VideoPlayerController.file(File(path));
    _c = c;
    await old?.dispose();
    try {
      await c.initialize();
      await c.setLooping(widget.loop);
      if (!mounted || _c != c) return;
      widget.onReady?.call(c.value.duration);
      if (widget.autoplay) await c.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final path = ref.watch(socialVideoPathProvider(widget.id));
    if (path == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: theme.colorScheme.surfaceContainerHighest),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(l10n.socVideoElsewhere, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      );
    }
    _load(path);
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      return const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.movie_outlined, color: Colors.white54))));
    }
    final video = AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c));
    return Semantics(
      button: true,
      label: c.value.isPlaying ? l10n.musPause : l10n.musPlay,
      child: GestureDetector(
        onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.fill ? 0 : 14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.fill) SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)))) else video,
              if (!c.value.isPlaying && !widget.autoplay)
                const DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exposed for stories (pause while holding).
  VideoPlayerController? get controller => _c;
}
