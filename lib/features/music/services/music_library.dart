import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:prism_plurality/core/diagnostics/perf_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/features/music/models/music_models.dart';

const _uuid = Uuid();

/// Where Prism keeps imported music (its own copies, so tracks keep
/// working after the original file is moved or deleted).
final musicDirProvider = FutureProvider<Directory>((ref) async {
  // Profiling builds play a stand-in track; no folder (and none on web).
  if (kPerfMode) return Directory('perf-music');
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'music'));
  await Directory(p.join(dir.path, 'files')).create(recursive: true);
  await Directory(p.join(dir.path, 'art')).create(recursive: true);
  return dir;
});

/// Synchronous access once resolved (null on web or before first load).
final musicDirPathProvider = Provider<String?>((ref) => ref.watch(musicDirProvider).value?.path);

String trackFilePath(String dir, Track t) => p.join(dir, 'files', t.file);
String? trackArtPath(String? dir, Track? t) => dir == null || t?.art == null ? null : p.join(dir, 'art', t!.art!);

/// Result of an import: what was added and what could not be.
@immutable
class ImportResult {
  const ImportResult({this.added = const [], this.unsupported = const [], this.failed = const []});

  final List<Track> added;

  /// File names with a format Prism does not offer.
  final List<String> unsupported;

  /// File names that could not be read or copied.
  final List<String> failed;
}

/// Tags read from an audio file.
typedef TrackTags = ({String? title, String? artist, String? album, int? durationMs, Uint8List? art, String? artMime});

typedef TagReader = TrackTags Function(File file);

TrackTags readTrackTags(File file) {
  try {
    final m = readMetadata(file, getImage: true);
    final pic = m.pictures.isEmpty ? null : m.pictures.first;
    return (
      title: m.title,
      artist: m.artist,
      album: m.album,
      durationMs: m.duration?.inMilliseconds,
      art: pic?.bytes,
      artMime: pic?.mimetype,
    );
  } catch (_) {
    // Unreadable or missing tags: the track still imports by file name.
    return (title: null, artist: null, album: null, durationMs: null, art: null, artMime: null);
  }
}

final tagReaderProvider = Provider<TagReader>((ref) => readTrackTags);

String _titleFromFileName(String name) => p.basenameWithoutExtension(name).replaceAll(RegExp(r'[_]+'), ' ').trim();

class MusicLibraryNotifier extends AsyncNotifier<MusicLibrary> {
  late Directory _dir;

  File get _file => File(p.join(_dir.path, 'library.json'));

  @override
  Future<MusicLibrary> build() async {
    if (kPerfMode) {
      return MusicLibrary(
        tracks: [
          Track(
            id: 'perf-track',
            file: 'perf.mp3',
            title: 'Profiling track',
            artist: 'Prism',
            durationMs: 30 * 60 * 1000,
            addedAt: DateTime.utc(2026),
          ),
        ],
      );
    }
    if (kIsWeb) return const MusicLibrary();
    _dir = await ref.watch(musicDirProvider.future);
    try {
      if (!await _file.exists()) return const MusicLibrary();
      return MusicLibrary.fromJson(jsonDecode(await _file.readAsString()));
    } catch (_) {
      return const MusicLibrary();
    }
  }

  Future<MusicLibrary> _cur() async => state.value ?? await future;

  Future<void> _save(MusicLibrary next) async {
    state = AsyncData(next);
    try {
      // Write-then-rename so a crash never leaves a half-written library.
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(jsonEncode(next.toJson()), flush: true);
      await tmp.rename(_file.path);
    } catch (_) {
      // Kept in memory for this session.
    }
  }

  /// Copies [paths] into the library and reads their tags.
  Future<ImportResult> importFiles(List<String> paths) async {
    final lib = await _cur();
    final reader = ref.read(tagReaderProvider);
    final added = <Track>[], unsupported = <String>[], failed = <String>[];
    for (final path in paths) {
      final name = p.basename(path);
      final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
      if (!supportedAudioExtensions.contains(ext)) {
        unsupported.add(name);
        continue;
      }
      try {
        final src = File(path);
        if (!await src.exists() || await src.length() == 0) {
          failed.add(name);
          continue;
        }
        final id = _uuid.v4();
        final fileName = '$id.$ext';
        final dest = await src.copy(p.join(_dir.path, 'files', fileName));
        final tags = reader(dest);
        String? art;
        if (tags.art != null && tags.art!.isNotEmpty) {
          art = '$id.${(tags.artMime ?? '').contains('png') ? 'png' : 'jpg'}';
          await File(p.join(_dir.path, 'art', art)).writeAsBytes(tags.art!);
        }
        added.add(
          Track(
            id: id,
            file: fileName,
            title: (tags.title?.trim().isNotEmpty ?? false) ? tags.title!.trim() : _titleFromFileName(name),
            artist: tags.artist?.trim() ?? '',
            album: tags.album?.trim() ?? '',
            durationMs: tags.durationMs ?? 0,
            art: art,
            addedAt: DateTime.now(),
          ),
        );
      } catch (_) {
        failed.add(name);
      }
    }
    if (added.isNotEmpty) await _save(lib.copyWith(tracks: [...lib.tracks, ...added]));
    return ImportResult(added: added, unsupported: unsupported, failed: failed);
  }

  Future<void> updateTrack(Track t) async {
    final lib = await _cur();
    await _save(lib.copyWith(tracks: [for (final x in lib.tracks) x.id == t.id ? t : x]));
  }

  Future<void> toggleFavorite(String id) async {
    final t = (await _cur()).track(id);
    if (t != null) await updateTrack(t.copyWith(favorite: !t.favorite));
  }

  /// Sets cover art from picked image bytes (null removes it).
  Future<void> setArt(String id, Uint8List? bytes) async {
    final t = (await _cur()).track(id);
    if (t == null) return;
    try {
      if (t.art != null) await File(p.join(_dir.path, 'art', t.art!)).delete();
    } catch (_) {}
    if (bytes == null) return updateTrack(t.copyWith(clearArt: true));
    // New name so cached images of the old cover are not reused.
    final name = '${t.id}-${DateTime.now().millisecondsSinceEpoch}.img';
    await File(p.join(_dir.path, 'art', name)).writeAsBytes(bytes);
    await updateTrack(t.copyWith(art: name));
  }

  /// Records a play: bumps the count and the recently-played list.
  Future<void> markPlayed(String id, {int? durationMs}) async {
    final lib = await _cur();
    final t = lib.track(id);
    if (t == null) return;
    final updated = t.copyWith(
      playCount: t.playCount + 1,
      lastPlayedAt: DateTime.now(),
      durationMs: (t.durationMs == 0 && durationMs != null) ? durationMs : null,
    );
    await _save(
      lib.copyWith(
        tracks: [for (final x in lib.tracks) x.id == id ? updated : x],
        recent: [id, ...lib.recent.where((r) => r != id)].take(50).toList(),
        plays: [...lib.plays.skip(lib.plays.length >= 5000 ? lib.plays.length - 4999 : 0), (id, DateTime.now())],
      ),
    );
  }

  Future<void> deleteTrack(String id) async {
    final lib = await _cur();
    final t = lib.track(id);
    if (t == null) return;
    for (final f in [p.join(_dir.path, 'files', t.file), if (t.art != null) p.join(_dir.path, 'art', t.art!)]) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
    await _save(
      lib.copyWith(
        tracks: [for (final x in lib.tracks) if (x.id != id) x],
        playlists: [for (final pl in lib.playlists) pl.copyWith(trackIds: [for (final x in pl.trackIds) if (x != id) x])],
        recent: [for (final r in lib.recent) if (r != id) r],
      ),
    );
  }

  Future<Playlist> createPlaylist(String name, {List<String> trackIds = const []}) async {
    final lib = await _cur();
    final pl = Playlist(id: _uuid.v4(), name: name.trim(), trackIds: trackIds);
    await _save(lib.copyWith(playlists: [...lib.playlists, pl]));
    return pl;
  }

  Future<void> updatePlaylist(Playlist pl) async {
    final lib = await _cur();
    await _save(lib.copyWith(playlists: [for (final x in lib.playlists) x.id == pl.id ? pl : x]));
  }

  Future<void> deletePlaylist(String id) async {
    final lib = await _cur();
    await _save(lib.copyWith(playlists: [for (final x in lib.playlists) if (x.id != id) x]));
  }

  Future<void> reorderPlaylists(int from, int to) async {
    final lib = await _cur();
    final list = [...lib.playlists];
    final pl = list.removeAt(from);
    list.insert(to.clamp(0, list.length), pl);
    await _save(lib.copyWith(playlists: list));
  }

  Future<void> addToPlaylist(String playlistId, String trackId) async {
    final lib = await _cur();
    await _save(
      lib.copyWith(
        playlists: [
          for (final x in lib.playlists)
            x.id == playlistId && !x.trackIds.contains(trackId) ? x.copyWith(trackIds: [...x.trackIds, trackId]) : x,
        ],
      ),
    );
  }
}

final musicLibraryProvider = AsyncNotifierProvider<MusicLibraryNotifier, MusicLibrary>(MusicLibraryNotifier.new);
