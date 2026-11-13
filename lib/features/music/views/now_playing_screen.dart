import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/accessibility/a11y_views.dart';
import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/features/music/views/mini_player.dart';
import 'package:prism_plurality/features/music/views/music_widgets.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_color_picker_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_switch_row.dart';

/// Expanded player: artwork, full controls, queue and player appearance.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _scrub;
  late final NowPlayingFlag _flag;

  @override
  void initState() {
    super.initState();
    _flag = ref.read(nowPlayingOpenProvider.notifier);
    // After the first frame: providers must not change during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _flag.set(true));
  }

  @override
  void dispose() {
    final f = _flag;
    Future.microtask(() => f.set(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(musicControllerProvider);
    final track = ref.watch(currentTrackProvider);
    final c = ref.read(musicControllerProvider.notifier);
    final look = state.look;
    final artBg = look.artworkBackground && track?.art != null;
    final base = look.color != null ? Color(look.color!) : theme.scaffoldBackgroundColor;
    final fg = artBg
        ? Colors.white
        : (ThemeData.estimateBrightnessForColor(base) == Brightness.dark ? Colors.white : Colors.black87);
    final pos = ref.watch(musicPositionProvider).value ?? Duration.zero;
    final total = state.durationMs;
    final value = _scrub ?? (total <= 0 ? 0.0 : (pos.inMilliseconds / total).clamp(0.0, 1.0));
    final shown = Duration(milliseconds: (value * total).round());

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _PlayerIntent('toggle'),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true): _PlayerIntent('next'),
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): _PlayerIntent('previous'),
      },
      child: Actions(
        actions: {
          _PlayerIntent: CallbackAction<_PlayerIntent>(
            onInvoke: (i) => switch (i.action) {
              'toggle' => c.toggle(),
              'next' => c.next(),
              _ => c.previous(),
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: base,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (artBg) ArtworkBackdrop(track: track, blur: look.blurArtwork, dim: 0.5),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                PlayerButton(
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  label: l10n.musClosePlayer,
                                  color: fg,
                                  onPressed: () => Navigator.of(context).maybePop(),
                                ),
                                Expanded(
                                  child: Text(
                                    state.queue.name ?? l10n.musNowPlaying,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(color: fg.withValues(alpha: 0.8)),
                                  ),
                                ),
                                PlayerButton(
                                  icon: Icons.tune_rounded,
                                  label: l10n.musPlayerLook,
                                  color: fg,
                                  onPressed: () => showPlayerLookSheet(context),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Center(
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    final side = box.biggest.shortestSide.clamp(80.0, 360.0);
                                    return TrackArt(track: track, size: side, radius: 20);
                                  },
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track?.title ?? l10n.musNothingPlaying,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleLarge?.copyWith(color: fg),
                                      ),
                                      if (track != null && (track.artist.isNotEmpty || track.album.isNotEmpty))
                                        Text(
                                          [track.artist, track.album].where((x) => x.isNotEmpty).join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.75)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (track != null)
                                  PlayerButton(
                                    icon: track.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    label: track.favorite ? l10n.musUnfavorite : l10n.musFavorite,
                                    color: fg,
                                    active: track.favorite,
                                    onPressed: () => ref.read(musicLibraryProvider.notifier).toggleFavorite(track.id),
                                  ),
                              ],
                            ),
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  l10n.musCannotPlay(state.error!),
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                ),
                              ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: fg,
                                inactiveTrackColor: fg.withValues(alpha: 0.25),
                                thumbColor: fg,
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: value,
                                semanticFormatterCallback: (v) =>
                                    '${formatTrackTime(Duration(milliseconds: (v * total).round()))} / ${formatTrackTime(Duration(milliseconds: total))}',
                                onChanged: total <= 0 ? null : (v) => setState(() => _scrub = v),
                                onChangeEnd: (v) async {
                                  await c.seek(Duration(milliseconds: (v * total).round()));
                                  if (mounted) setState(() => _scrub = null);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(formatTrackTime(shown), style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8))),
                                  Text(
                                    formatTrackTime(Duration(milliseconds: total)),
                                    style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                PlayerButton(
                                  icon: Icons.shuffle_rounded,
                                  label: l10n.musShuffle,
                                  color: fg,
                                  active: state.queue.shuffle,
                                  onPressed: c.toggleShuffle,
                                ),
                                PlayerButton(icon: Icons.skip_previous_rounded, label: l10n.musPrevious, color: fg, size: 52, iconSize: 32, onPressed: c.previous),
                                PlayerButton(
                                  icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  label: state.playing ? l10n.musPause : l10n.musPlay,
                                  color: fg,
                                  filled: true,
                                  size: 68,
                                  iconSize: 38,
                                  onPressed: state.hasTrack ? c.toggle : null,
                                ),
                                PlayerButton(icon: Icons.skip_next_rounded, label: l10n.musNext, color: fg, size: 52, iconSize: 32, onPressed: c.next),
                                PlayerButton(
                                  icon: state.queue.repeat == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                  label: switch (state.queue.repeat) {
                                    RepeatMode.off => l10n.musRepeatOff,
                                    RepeatMode.all => l10n.musRepeatAll,
                                    RepeatMode.one => l10n.musRepeatOne,
                                  },
                                  color: fg,
                                  active: state.queue.repeat != RepeatMode.off,
                                  onPressed: c.cycleRepeat,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.volume_down_rounded, color: fg.withValues(alpha: 0.8), size: 20),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: fg.withValues(alpha: 0.8),
                                      inactiveTrackColor: fg.withValues(alpha: 0.2),
                                      thumbColor: fg,
                                      trackHeight: 2,
                                    ),
                                    child: Slider(
                                      value: state.volume,
                                      semanticFormatterCallback: (v) => l10n.musVolumeValue((v * 100).round()),
                                      onChanged: c.setVolume,
                                    ),
                                  ),
                                ),
                                PlayerButton(
                                  icon: Icons.queue_music_rounded,
                                  label: l10n.musQueue,
                                  color: fg,
                                  onPressed: () => showQueueSheet(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerIntent extends Intent {
  const _PlayerIntent(this.action);
  final String action;
}

Future<void> showQueueSheet(BuildContext context) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (context, scroll) => _QueueSheet(scroll: scroll),
);

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final queue = ref.watch(musicControllerProvider.select((s) => s.queue));
    final lib = ref.watch(musicLibraryProvider).value ?? const MusicLibrary();
    final c = ref.read(musicControllerProvider.notifier);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: l10n.musQueueTitle(queue.items.length)),
          Expanded(
            child: queue.isEmpty
                ? Center(child: Text(l10n.musQueueEmpty))
                : ReorderableListView.builder(
                    scrollController: scroll,
                    buildDefaultDragHandles: false,
                    itemCount: queue.items.length,
                    onReorderItem: c.moveInQueue,
                    itemBuilder: (context, i) {
                      final t = lib.track(queue.items[i]);
                      final current = i == queue.index;
                      return Material(
                        key: ValueKey('$i-${queue.items[i]}'),
                        color: current ? theme.colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                        child: InkWell(
                          onTap: () => c.jumpTo(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                TrackArt(track: t, size: 40),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t?.title ?? '?',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: current ? FontWeight.w700 : null),
                                      ),
                                      if (t != null && t.artist.isNotEmpty)
                                        Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                PlayerButton(
                                  icon: Icons.close_rounded,
                                  label: l10n.musRemoveFromQueue,
                                  size: 40,
                                  iconSize: 20,
                                  onPressed: () async {
                                    if (await confirmIfAsked(context, ref, title: l10n.musRemoveFromQueue)) await c.removeFromQueue(i);
                                  },
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: Semantics(
                                    label: l10n.musReorder,
                                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Player appearance: layout, placement, artwork background, colour.
Future<void> showPlayerLookSheet(BuildContext context) => PrismSheet.show<void>(
  context: context,
  title: context.l10n.musPlayerLook,
  builder: (context) => const _LookSheet(),
);

class _LookSheet extends ConsumerWidget {
  const _LookSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final look = ref.watch(musicControllerProvider.select((s) => s.look));
    final c = ref.read(musicControllerProvider.notifier);
    const swatches = [0xFF7E57C2, 0xFF5C6BC0, 0xFF26A69A, 0xFFEC407A, 0xFFFF7043, 0xFF263238, 0xFF000000];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.musLayout, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          PrismSegmentedControl<PlayerLayout>(
            segments: [
              PrismSegment(value: PlayerLayout.bar, label: l10n.musLayoutBar),
              PrismSegment(value: PlayerLayout.bubble, label: l10n.musLayoutBubble),
              PrismSegment(value: PlayerLayout.hidden, label: l10n.musLayoutHidden),
            ],
            selected: look.layout,
            onChanged: (v) => c.setLook(look.copyWith(layout: v)),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.musLayoutHelp,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (look.layout == PlayerLayout.bar) ...[
            const SizedBox(height: 12),
            Text(l10n.musPlacement, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            PrismSegmentedControl<PlayerPlacement>(
              segments: [
                PrismSegment(value: PlayerPlacement.bottom, label: l10n.musPlacementBottom),
                PrismSegment(value: PlayerPlacement.top, label: l10n.musPlacementTop),
              ],
              selected: look.placement,
              onChanged: (v) => c.setLook(look.copyWith(placement: v)),
            ),
          ],
          PrismSwitchRow(
            title: l10n.musArtworkBg,
            subtitle: l10n.musArtworkBgHelp,
            value: look.artworkBackground,
            onChanged: (v) => c.setLook(look.copyWith(artworkBackground: v)),
          ),
          if (look.artworkBackground)
            PrismSwitchRow(
              title: l10n.musBlurArtwork,
              value: look.blurArtwork,
              onChanged: (v) => c.setLook(look.copyWith(blurArtwork: v)),
            ),
          const SizedBox(height: 8),
          Text(l10n.musPlayerColor, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrismChip(label: l10n.musColorTheme, selected: look.color == null, onTap: () => c.setLook(look.copyWith(clearColor: true))),
              for (final s in swatches)
                Semantics(
                  button: true,
                  selected: look.color == s,
                  label: '#${s.toRadixString(16).substring(2).toUpperCase()}',
                  child: InkResponse(
                    onTap: () => c.setLook(look.copyWith(color: s)),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(s),
                        shape: BoxShape.circle,
                        border: Border.all(width: look.color == s ? 3 : 1, color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
                ),
              PrismButton(
                label: l10n.fnColorCustom,
                density: PrismControlDensity.compact,
                onPressed: () async {
                  final hex = await showPrismColorPickerDialog(context: context, initialColor: Color(look.color ?? 0xFF7E57C2));
                  final v = hex == null ? null : int.tryParse(hex.replaceFirst('#', ''), radix: 16);
                  if (v != null) c.setLook(look.copyWith(color: 0xFF000000 | v));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
