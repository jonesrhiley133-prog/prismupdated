import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Cover art for a track, or a music-note placeholder.
class TrackArt extends ConsumerWidget {
  const TrackArt({super.key, required this.track, this.size = 44, this.radius = 8});

  final Track? track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final path = trackArtPath(ref.watch(musicDirPathProvider), track);
    final placeholder = Container(
      width: size,
      height: size,
      color: theme.colorScheme.primary.withValues(alpha: 0.18),
      child: Icon(Icons.music_note_rounded, size: size * 0.5, color: theme.colorScheme.primary),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: path == null
          ? placeholder
          : Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (size * 3).round().clamp(64, 1200),
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Blurred cover art used behind the expanded and compact players.
class ArtworkBackdrop extends ConsumerWidget {
  const ArtworkBackdrop({super.key, required this.track, required this.blur, this.dim = 0.45});

  final Track? track;
  final bool blur;
  final double dim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = trackArtPath(ref.watch(musicDirPathProvider), track);
    if (path == null) return const SizedBox.shrink();
    // A tiny decode stretched to fill looks like a heavy blur but costs
    // almost nothing; a live blur filter would be redone every frame.
    final Widget img = Image.file(
      File(path),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: blur ? 20 : 240,
      filterQuality: blur ? FilterQuality.medium : FilterQuality.low,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          img,
          ColoredBox(color: Colors.black.withValues(alpha: dim)),
        ],
      ),
    );
  }
}

/// Round control with a screen-reader label. Works above the navigator
/// (no Tooltip/Overlay needed), so the floating player can use it.
class PlayerButton extends StatelessWidget {
  const PlayerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 24,
    this.color,
    this.filled = false,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final bool filled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      toggled: active ? true : null,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: Material(
        color: filled ? fg : (active ? fg.withValues(alpha: 0.16) : Colors.transparent),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: filled
                  ? (fg.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                  : fg.withValues(alpha: onPressed == null ? 0.4 : 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin progress line for the compact players.
class PlayerProgressLine extends ConsumerWidget {
  const PlayerProgressLine({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(musicPositionProvider).value ?? Duration.zero;
    final total = ref.watch(musicControllerProvider.select((s) => s.durationMs));
    final f = total <= 0 ? 0.0 : (pos.inMilliseconds / total).clamp(0.0, 1.0);
    return Semantics(
      label: context.l10n.musProgress,
      value: '${formatTrackTime(pos)} / ${formatTrackTime(Duration(milliseconds: total))}',
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            ColoredBox(color: color.withValues(alpha: 0.2), child: const SizedBox.expand()),
            FractionallySizedBox(widthFactor: f, child: ColoredBox(color: color, child: const SizedBox.expand())),
          ],
        ),
      ),
    );
  }
}
