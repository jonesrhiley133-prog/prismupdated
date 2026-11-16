import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:prism_plurality/features/accessibility/a11y_views.dart';
import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/features/music/views/mini_player.dart';
import 'package:prism_plurality/features/music/views/music_widgets.dart';
import 'package:prism_plurality/features/music/views/now_playing_screen.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/app_shell.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_chip.dart';
import 'package:prism_plurality/shared/widgets/prism_dialog.dart';
import 'package:prism_plurality/shared/widgets/prism_loading_state.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_segmented_control.dart';
import 'package:prism_plurality/shared/widgets/prism_sheet.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_toast.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar_action.dart';

enum _Tab { songs, playlists, favorites, recent }

/// Picks audio files with the system picker and adds them to the library,
/// telling the user plainly about anything that could not be imported.
Future<void> importMusic(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  if (kIsWeb) {
    PrismToast.show(context, message: l10n.musWebUnsupported);
    return;
  }
  FilePickerResult? picked;
  try {
    picked = await FilePicker.pickFiles(type: FileType.audio, allowMultiple: true);
  } catch (_) {
    if (context.mounted) PrismToast.error(context, message: l10n.musPickerFailed);
    return;
  }
  if (picked == null || !context.mounted) return;
  final paths = [for (final f in picked.files) ?f.path];
  if (paths.isEmpty) {
    PrismToast.error(context, message: l10n.musPickerFailed);
    return;
  }
  final result = await ref.read(musicLibraryProvider.notifier).importFiles(paths);
  if (!context.mounted) return;
  if (result.unsupported.isEmpty && result.failed.isEmpty) {
    PrismToast.success(context, message: l10n.musImported(result.added.length));
    return;
  }
  await PrismDialog.show<void>(
    context: context,
    title: l10n.musImportReport,
    builder: (context) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.musImported(result.added.length)),
          if (result.unsupported.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.musUnsupportedFormat(supportedAudioExtensions.map((e) => e.toUpperCase()).join(', ')), style: Theme.of(context).textTheme.labelLarge),
            for (final n in result.unsupported) Text('• $n'),
          ],
          if (result.failed.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.musImportFailed, style: Theme.of(context).textTheme.labelLarge),
            for (final n in result.failed) Text('• $n'),
          ],
        ],
      ),
    ),
  );
}

String _sortLabel(AppLocalizations l10n, TrackSort s) => switch (s) {
  TrackSort.title => l10n.musSortTitle,
  TrackSort.artist => l10n.musSortArtist,
  TrackSort.album => l10n.musSortAlbum,
  TrackSort.recentlyAdded => l10n.musSortAdded,
  TrackSort.mostPlayed => l10n.musSortPlayed,
};

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  _Tab _tab = _Tab.songs;
  String _query = '';
  TrackSort _sort = TrackSort.title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final async = ref.watch(musicLibraryProvider);
    final player = ref.watch(musicControllerProvider.select((s) => (s.hasTrack, s.look.layout)));
    final showOpen = player.$1 && player.$2 == PlayerLayout.hidden;
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: l10n.musTitle,
        actions: [
          PrismTopBarAction(icon: Icons.tune_rounded, tooltip: l10n.musPlayerLook, onPressed: () => showPlayerLookSheet(context)),
          PrismTopBarAction(icon: Icons.add_rounded, tooltip: l10n.musImport, onPressed: () => importMusic(context, ref)),
        ],
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: async.when(
        loading: () => const PrismLoadingState(),
        error: (e, _) => Center(child: Text(l10n.errorWithDetail(e))),
        data: (lib) {
          final c = ref.read(musicControllerProvider.notifier);
          final List<Track> tracks = switch (_tab) {
            _Tab.songs => filterTracks(lib.tracks, query: _query, sort: _sort),
            _Tab.favorites => filterTracks(lib.tracks.where((t) => t.favorite), query: _query, sort: _sort),
            _Tab.recent => lib.resolve(lib.recent),
            _Tab.playlists => const [],
          };
          final queueName = switch (_tab) {
            _Tab.favorites => l10n.musFavorites,
            _Tab.recent => l10n.musRecent,
            _ => l10n.musAllSongs,
          };
          final children = <Widget>[
            PrismSegmentedControl<_Tab>(
              segments: [
                PrismSegment(value: _Tab.songs, label: l10n.musAllSongs),
                PrismSegment(value: _Tab.playlists, label: l10n.musPlaylists),
                PrismSegment(value: _Tab.favorites, label: l10n.musFavorites),
                PrismSegment(value: _Tab.recent, label: l10n.musRecent),
              ],
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 10),
            if (_tab == _Tab.playlists)
              _Playlists(lib: lib)
            else ...[
              if (_tab != _Tab.recent && lib.tracks.isNotEmpty) ...[
                PrismTextField(
                  hintText: l10n.musSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in TrackSort.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: PrismChip(label: _sortLabel(l10n, s), selected: _sort == s, onTap: () => setState(() => _sort = s)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (showOpen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrismButton(label: l10n.musOpenPlayer, expanded: true, onPressed: () => openNowPlaying(ref)),
                ),
              if (tracks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      PrismButton(
                        label: l10n.musPlayAll,
                        tone: PrismButtonTone.filled,
                        onPressed: () => c.playTracks([for (final t in tracks) t.id], name: queueName),
                      ),
                      const SizedBox(width: 8),
                      PrismButton(
                        label: l10n.musShuffle,
                        onPressed: () {
                          if (!ref.read(musicControllerProvider).queue.shuffle) c.toggleShuffle();
                          final ids = [for (final t in tracks) t.id]..shuffle();
                          c.playTracks(ids, name: queueName);
                        },
                      ),
                      const Spacer(),
                      Text(l10n.musSongCount(tracks.length), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              if (lib.tracks.isEmpty)
                _Empty(
                  title: l10n.musEmptyTitle,
                  message: l10n.musEmptyMessage(supportedAudioExtensions.take(5).map((e) => e.toUpperCase()).join(', ')),
                  action: PrismButton(label: l10n.musImport, tone: PrismButtonTone.filled, onPressed: () => importMusic(context, ref)),
                )
              else if (tracks.isEmpty)
                _Empty(
                  title: switch (_tab) {
                    _Tab.favorites => l10n.musNoFavorites,
                    _Tab.recent => l10n.musNoRecent,
                    _ => l10n.musNoResults,
                  },
                ),
              for (var i = 0; i < tracks.length; i++)
                TrackTile(
                  track: tracks[i],
                  onTap: () => c.playTracks([for (final t in tracks) t.id], start: i, name: queueName),
                ),
            ],
            SizedBox(height: NavBarInset.of(context) + 96),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.message, this.action});

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.library_music_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class TrackTile extends ConsumerWidget {
  const TrackTile({super.key, required this.track, required this.onTap, this.trailing});

  final Track track;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current = ref.watch(musicControllerProvider.select((s) => s.currentId == track.id));
    final playing = ref.watch(musicControllerProvider.select((s) => s.playing && s.currentId == track.id));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PrismSurface(
        padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
        tone: current ? PrismSurfaceTone.accent : PrismSurfaceTone.subtle,
        semanticLabel: l10n.musTrackLabel(track.title, track.artist.isEmpty ? l10n.musUnknownArtist : track.artist),
        onTap: onTap,
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                TrackArt(track: track),
                if (playing) const Icon(Icons.graphic_eq_rounded, color: Colors.white, shadows: [Shadow(blurRadius: 6)]),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                    Text(
                      [
                        track.artist.isEmpty ? l10n.musUnknownArtist : track.artist,
                        if (track.album.isNotEmpty) track.album,
                        if (track.durationMs > 0) formatTrackTime(track.duration),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            PlayerButton(
              icon: track.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: track.favorite ? l10n.musUnfavorite : l10n.musFavorite,
              size: 40,
              iconSize: 20,
              color: track.favorite ? theme.colorScheme.primary : null,
              onPressed: () => ref.read(musicLibraryProvider.notifier).toggleFavorite(track.id),
            ),
            trailing ??
                PlayerButton(
                  icon: Icons.more_vert_rounded,
                  label: l10n.musTrackOptions,
                  size: 40,
                  iconSize: 20,
                  onPressed: () => showTrackMenu(context, track.id),
                ),
          ],
        ),
      ),
    );
  }
}

Future<void> showTrackMenu(BuildContext context, String trackId) => PrismSheet.show<void>(
  context: context,
  builder: (context) => _TrackMenu(trackId: trackId),
);

class _TrackMenu extends ConsumerWidget {
  const _TrackMenu({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lib = ref.watch(musicLibraryProvider).value ?? const MusicLibrary();
    final track = lib.track(trackId);
    if (track == null) return const SizedBox.shrink();
    final c = ref.read(musicControllerProvider.notifier);
    final n = ref.read(musicLibraryProvider.notifier);
    Widget item(IconData icon, String label, VoidCallback onTap, {bool destructive = false}) => _MenuRow(
      icon: icon,
      label: label,
      destructive: destructive,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TrackArt(track: track, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (track.artist.isNotEmpty) Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          item(Icons.playlist_play_rounded, l10n.musPlayNext, () => c.playNext(trackId)),
          item(Icons.queue_music_rounded, l10n.musAddToQueue, () => c.addToQueue(trackId)),
          item(Icons.playlist_add_rounded, l10n.musAddToPlaylist, () => showAddToPlaylist(context, trackId)),
          item(Icons.edit_rounded, l10n.musEditInfo, () => showTrackEditor(context, trackId)),
          item(Icons.delete_outline_rounded, l10n.musDeleteTrack, () async {
            final ok = await PrismDialog.confirm(
              context: context,
              title: l10n.musDeleteTrackTitle,
              message: l10n.musDeleteTrackMessage(track.title),
              confirmLabel: l10n.delete,
              cancelLabel: l10n.cancel,
              destructive: true,
            );
            if (!ok) return;
            await c.forgetTrack(trackId);
            await n.deleteTrack(trackId);
          }, destructive: true),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: color))),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAddToPlaylist(BuildContext context, String trackId) => PrismSheet.show<void>(
  context: context,
  title: context.l10n.musAddToPlaylist,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final l10n = context.l10n;
      final lib = ref.watch(musicLibraryProvider).value ?? const MusicLibrary();
      final n = ref.read(musicLibraryProvider.notifier);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuRow(
              icon: Icons.add_rounded,
              label: l10n.musNewPlaylist,
              onTap: () async {
                final name = await _askName(context, l10n.musNewPlaylist);
                if (name == null) return;
                await n.createPlaylist(name, trackIds: [trackId]);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            for (final pl in lib.playlists)
              _MenuRow(
                icon: pl.trackIds.contains(trackId) ? Icons.check_rounded : Icons.queue_music_rounded,
                label: pl.name,
                onTap: () async {
                  await n.addToPlaylist(pl.id, trackId);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    PrismToast.success(context, message: l10n.musAddedTo(pl.name));
                  }
                },
              ),
          ],
        ),
      );
    },
  ),
);

Future<String?> _askName(BuildContext context, String title, {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final l10n = context.l10n;
  final ok = await PrismDialog.show<bool>(
    context: context,
    title: title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PrismTextField(controller: controller, autofocus: true, labelText: l10n.musPlaylistName, onSubmitted: (_) => Navigator.of(context).pop(true)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PrismButton(label: l10n.cancel, onPressed: () => Navigator.of(context).pop(false)),
            const SizedBox(width: 8),
            PrismButton(label: l10n.save, tone: PrismButtonTone.filled, onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      ],
    ),
  );
  final name = controller.text.trim();
  return ok == true && name.isNotEmpty ? name : null;
}

class _Playlists extends ConsumerWidget {
  const _Playlists({required this.lib});

  final MusicLibrary lib;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final n = ref.read(musicLibraryProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrismButton(
          label: l10n.musNewPlaylist,
          onPressed: () async {
            final name = await _askName(context, l10n.musNewPlaylist);
            if (name != null) await n.createPlaylist(name);
          },
        ),
        const SizedBox(height: 10),
        if (lib.playlists.isEmpty) _Empty(title: l10n.musNoPlaylists, message: l10n.musNoPlaylistsHelp),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: lib.playlists.length,
          onReorderItem: n.reorderPlaylists,
          itemBuilder: (context, i) {
            final pl = lib.playlists[i];
            final tracks = lib.resolve(pl.trackIds);
            return Padding(
              key: ValueKey(pl.id),
              padding: const EdgeInsets.only(bottom: 6),
              child: PrismSurface(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                onTap: () => showPlaylist(context, pl.id),
                child: Row(
                  children: [
                    TrackArt(track: tracks.firstOrNull, size: 48),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pl.name, style: theme.textTheme.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(l10n.musSongCount(tracks.length), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Semantics(
                        label: l10n.musReorder,
                        child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.drag_handle_rounded)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> showPlaylist(BuildContext context, String playlistId) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (context, scroll) => _PlaylistSheet(playlistId: playlistId, scroll: scroll),
);

class _PlaylistSheet extends ConsumerWidget {
  const _PlaylistSheet({required this.playlistId, required this.scroll});

  final String playlistId;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lib = ref.watch(musicLibraryProvider).value ?? const MusicLibrary();
    final pl = lib.playlists.where((p) => p.id == playlistId).firstOrNull;
    if (pl == null) return const SizedBox.shrink();
    final tracks = lib.resolve(pl.trackIds);
    final ids = [for (final t in tracks) t.id];
    final n = ref.read(musicLibraryProvider.notifier);
    final c = ref.read(musicControllerProvider.notifier);
    return SafeArea(
      child: Column(
        children: [
          PrismSheetTopBar(title: pl.name),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrismButton(
                  label: l10n.musPlayAll,
                  tone: PrismButtonTone.filled,
                  enabled: ids.isNotEmpty,
                  onPressed: () => c.playTracks(ids, name: pl.name),
                ),
                PrismButton(
                  label: l10n.musRename,
                  onPressed: () async {
                    final name = await _askName(context, l10n.musRename, initial: pl.name);
                    if (name != null) await n.updatePlaylist(pl.copyWith(name: name));
                  },
                ),
                PrismButton(
                  label: l10n.delete,
                  tone: PrismButtonTone.destructive,
                  onPressed: () async {
                    final ok = await PrismDialog.confirm(
                      context: context,
                      title: l10n.musDeletePlaylistTitle,
                      message: l10n.musDeletePlaylistMessage(pl.name),
                      confirmLabel: l10n.delete,
                      cancelLabel: l10n.cancel,
                      destructive: true,
                    );
                    if (!ok) return;
                    await n.deletePlaylist(pl.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: tracks.isEmpty
                ? _Empty(title: l10n.musPlaylistEmpty, message: l10n.musPlaylistEmptyHelp)
                : ReorderableListView.builder(
                    scrollController: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    buildDefaultDragHandles: false,
                    itemCount: tracks.length,
                    onReorderItem: (from, to) {
                      final next = [...ids];
                      final id = next.removeAt(from);
                      next.insert(to.clamp(0, next.length), id);
                      n.updatePlaylist(pl.copyWith(trackIds: next));
                    },
                    itemBuilder: (context, i) => TrackTile(
                      key: ValueKey('$i-${tracks[i].id}'),
                      track: tracks[i],
                      onTap: () => c.playTracks(ids, start: i, name: pl.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerButton(
                            icon: Icons.remove_circle_outline_rounded,
                            label: l10n.musRemoveFromPlaylist,
                            size: 40,
                            iconSize: 20,
                            onPressed: () async {
                              if (await confirmIfAsked(context, ref, title: l10n.musRemoveFromPlaylist)) {
                                await n.updatePlaylist(pl.copyWith(trackIds: [...ids]..removeAt(i)));
                              }
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
          ),
        ],
      ),
    );
  }
}

Future<void> showTrackEditor(BuildContext context, String trackId) => PrismSheet.show<void>(
  context: context,
  title: context.l10n.musEditInfo,
  builder: (context) => _TrackEditor(trackId: trackId),
);

class _TrackEditor extends ConsumerStatefulWidget {
  const _TrackEditor({required this.trackId});

  final String trackId;

  @override
  ConsumerState<_TrackEditor> createState() => _TrackEditorState();
}

class _TrackEditorState extends ConsumerState<_TrackEditor> {
  late final TextEditingController _title, _artist, _album;

  @override
  void initState() {
    super.initState();
    final t = ref.read(musicLibraryProvider).value?.track(widget.trackId);
    _title = TextEditingController(text: t?.title ?? '');
    _artist = TextEditingController(text: t?.artist ?? '');
    _album = TextEditingController(text: t?.album ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final track = ref.watch(musicLibraryProvider).value?.track(widget.trackId);
    if (track == null) return const SizedBox.shrink();
    final n = ref.read(musicLibraryProvider.notifier);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TrackArt(track: track, size: 72, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PrismButton(
                      label: l10n.musChooseCover,
                      density: PrismControlDensity.compact,
                      onPressed: () async {
                        final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 88);
                        if (f != null) await n.setArt(track.id, await f.readAsBytes());
                      },
                    ),
                    if (track.art != null)
                      PrismButton(
                        label: l10n.musRemoveCover,
                        density: PrismControlDensity.compact,
                        tone: PrismButtonTone.destructive,
                        onPressed: () => n.setArt(track.id, null),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrismTextField(controller: _title, labelText: l10n.musFieldTitle),
          const SizedBox(height: 8),
          PrismTextField(controller: _artist, labelText: l10n.musFieldArtist),
          const SizedBox(height: 8),
          PrismTextField(controller: _album, labelText: l10n.musFieldAlbum),
          const SizedBox(height: 14),
          PrismButton(
            label: l10n.save,
            tone: PrismButtonTone.filled,
            expanded: true,
            onPressed: () async {
              final title = _title.text.trim();
              await n.updateTrack(
                track.copyWith(title: title.isEmpty ? track.title : title, artist: _artist.text.trim(), album: _album.text.trim()),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
