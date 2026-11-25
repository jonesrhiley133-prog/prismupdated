import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/router/app_router.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/features/music/views/music_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Whether the expanded player is on screen (the compact one hides then).
final nowPlayingOpenProvider = NotifierProvider<NowPlayingFlag, bool>(NowPlayingFlag.new);

class NowPlayingFlag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) {
    if (ref.mounted && state != v) state = v;
  }
}

/// Hosts the app-wide compact player above every page. It sits outside
/// the navigator, so changing pages never rebuilds or restarts it.
class MusicPlayerHost extends ConsumerWidget {
  const MusicPlayerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        child,
        const _FloatingPlayer(),
      ],
    );
  }
}

void openNowPlaying(WidgetRef ref) {
  if (ref.read(nowPlayingOpenProvider)) return;
  ref.read(routerProvider).push(AppRoutePaths.nowPlaying);
}

class _FloatingPlayer extends ConsumerWidget {
  const _FloatingPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(musicControllerProvider.select((s) => s.hasTrack));
    final look = ref.watch(musicControllerProvider.select((s) => s.look));
    final expanded = ref.watch(nowPlayingOpenProvider);
    final mq = MediaQuery.of(context);
    // Out of the way while typing, on the full player, or when hidden.
    if (!hasTrack || expanded || look.layout == PlayerLayout.hidden || mq.viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    if (look.layout == PlayerLayout.bubble) return _Bubble(look: look);
    final wide = mq.size.width >= 720;
    return Positioned(
      left: wide ? null : 12,
      right: 12,
      width: wide ? 380 : null,
      top: look.placement == PlayerPlacement.top ? mq.padding.top + 64 : null,
      bottom: look.placement == PlayerPlacement.bottom ? mq.padding.bottom + (wide ? 16 : 92) : null,
      child: _Bar(look: look),
    );
  }
}

class _Bar extends ConsumerWidget {
  const _Bar({required this.look});

  final PlayerLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final track = ref.watch(currentTrackProvider);
    final playing = ref.watch(musicControllerProvider.select((s) => s.playing));
    final c = ref.read(musicControllerProvider.notifier);
    final artBg = look.artworkBackground && track?.art != null;
    final base = look.color != null ? Color(look.color!) : theme.colorScheme.surfaceContainerHigh;
    final fg = artBg
        ? Colors.white
        : (ThemeData.estimateBrightnessForColor(base) == Brightness.dark ? Colors.white : Colors.black87);
    return Semantics(
      container: true,
      label: l10n.musPlayerRegion,
      child: Material(
        color: base,
        elevation: 6,
        borderRadius: prismCorners(context, 18),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (artBg) Positioned.fill(child: ArtworkBackdrop(track: track, blur: look.blurArtwork)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => openNowPlaying(ref),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                    child: Row(
                      children: [
                        TrackArt(track: track, size: 42),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Semantics(
                            button: true,
                            hint: l10n.musOpenPlayer,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track?.title ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                                ),
                                if (track != null && track.artist.isNotEmpty)
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.75)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        PlayerButton(
                          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          label: playing ? l10n.musPause : l10n.musPlay,
                          color: fg,
                          onPressed: c.toggle,
                        ),
                        PlayerButton(icon: Icons.skip_next_rounded, label: l10n.musNext, color: fg, onPressed: c.next),
                        PlayerButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: l10n.musMinimize,
                          color: fg,
                          size: 36,
                          onPressed: () => c.setLook(look.copyWith(layout: PlayerLayout.bubble)),
                        ),
                      ],
                    ),
                  ),
                ),
                PlayerProgressLine(color: fg),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimized player: a small draggable disc that keeps playback one tap away.
class _Bubble extends ConsumerStatefulWidget {
  const _Bubble({required this.look});

  final PlayerLook look;

  @override
  ConsumerState<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends ConsumerState<_Bubble> {
  Offset? _drag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    const size = 56.0;
    final area = Rect.fromLTRB(8, mq.padding.top + 8, mq.size.width - size - 8, mq.size.height - mq.padding.bottom - size - 8);
    final pos = _drag ??
        Offset(
          area.left + (area.width) * widget.look.bubbleX,
          area.top + (area.height) * widget.look.bubbleY,
        );
    final track = ref.watch(currentTrackProvider);
    final playing = ref.watch(musicControllerProvider.select((s) => s.playing));
    final c = ref.read(musicControllerProvider.notifier);
    return Positioned(
      left: pos.dx.clamp(area.left, area.right),
      top: pos.dy.clamp(area.top, area.bottom),
      child: Semantics(
        button: true,
        label: l10n.musBubbleLabel(track?.title ?? ''),
        hint: l10n.musOpenPlayer,
        onLongPress: c.toggle,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => openNowPlaying(ref),
          onDoubleTap: c.toggle,
          onLongPress: () => c.setLook(widget.look.copyWith(layout: PlayerLayout.bar)),
          onPanUpdate: (d) => setState(() => _drag = pos + d.delta),
          onPanEnd: (_) {
            final p = _drag ?? pos;
            // Snap to the nearest side so it never covers the middle.
            final snapX = p.dx + size / 2 < mq.size.width / 2 ? 0.0 : 1.0;
            c.setLook(
              widget.look.copyWith(
                bubbleX: snapX,
                bubbleY: area.height <= 0 ? 0.5 : ((p.dy - area.top) / area.height).clamp(0.0, 1.0),
              ),
            );
            setState(() => _drag = null);
          },
          child: Material(
            elevation: 6,
            shape: prismCircleBorder(context, side: BorderSide(color: theme.colorScheme.primary, width: 2)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TrackArt(track: track, size: size, radius: 0),
                  if (!playing)
                    const ColoredBox(
                      color: Colors.black45,
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
