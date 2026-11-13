import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';
import 'package:prism_plurality/features/music/services/music_player.dart';
import 'package:prism_plurality/features/music/views/mini_player.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';

class FakeEngine implements AudioEngine {
  static int instances = 0;
  FakeEngine() {
    instances++;
  }

  final loads = <String>[];
  final _playing = StreamController<bool>.broadcast();
  final _done = StreamController<void>.broadcast();
  final _pos = StreamController<Duration>.broadcast();
  Duration pos = Duration.zero;
  bool isPlaying = false;
  double volume = 1;
  bool failNext = false;

  void finishTrack() => _done.add(null);

  @override
  Future<Duration?> load(String path, {Duration position = Duration.zero}) async {
    if (failNext) {
      failNext = false;
      throw const FileSystemException('bad');
    }
    loads.add(p.basename(path));
    pos = position;
    return const Duration(minutes: 3);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() => pause();
  @override
  Future<void> seek(Duration position) async => pos = position;
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Duration get position => pos;
  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<void> get completedStream => _done.stream;
  @override
  Future<void> dispose() async {}
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('PlayQueue', () {
    const q0 = PlayQueue();
    List<String> rev(List<String> l) => l.reversed.toList();

    test('next/previous respect repeat modes', () {
      var q = q0.load(['a', 'b', 'c'], start: 1);
      expect(q.current, 'b');
      q = q.next()!;
      expect(q.current, 'c');
      expect(q.next(), isNull, reason: 'end of queue with repeat off stops');
      expect(q.setRepeat(RepeatMode.all).next()!.current, 'a');
      expect(q.setRepeat(RepeatMode.one).next(auto: true)!.current, 'c');
      expect(q.setRepeat(RepeatMode.one).next()!.current, 'a', reason: 'manual skip still moves on');
      expect(q.previous().current, 'b');
      expect(q0.load(['a', 'b']).previous().current, 'a');
    });

    test('shuffle keeps the current track and can be undone', () {
      var q = q0.load(['a', 'b', 'c', 'd'], start: 2).setShuffle(true, shuffler: rev);
      expect(q.items, ['c', 'd', 'b', 'a']);
      expect(q.current, 'c');
      q = q.next()!;
      expect(q.current, 'd');
      q = q.setShuffle(false);
      expect(q.items, ['a', 'b', 'c', 'd']);
      expect(q.current, 'd');
    });

    test('queue editing keeps the playing track', () {
      var q = q0.load(['a', 'b', 'c'], start: 1).playNext('x').add('y');
      expect(q.items, ['a', 'b', 'x', 'c', 'y']);
      expect(q.current, 'b');
      q = q.move(0, 4);
      expect(q.items, ['b', 'x', 'c', 'y', 'a']);
      expect(q.current, 'b');
      q = q.move(0, 2);
      expect(q.current, 'b');
      expect(q.index, 2);
      q = q.removeAt(0);
      expect(q.current, 'b');
      q = q.removeTrack('b');
      expect(q.items.contains('b'), isFalse);
      expect(q.current, isNotNull);
    });

    test('round trips through JSON', () {
      final q = q0.load(['a', 'b'], start: 1, name: 'Mix').setRepeat(RepeatMode.all);
      final back = PlayQueue.fromJson(q.toJson());
      expect(back.items, q.items);
      expect(back.index, 1);
      expect(back.repeat, RepeatMode.all);
      expect(back.name, 'Mix');
      expect(PlayQueue.fromJson({'items': ['a'], 'index': 9}).index, 0);
    });
  });

  test('search, sort and time formatting', () {
    final t0 = DateTime(2026);
    final tracks = [
      Track(id: '1', file: '1.mp3', title: 'Zebra', artist: 'Ann', addedAt: t0, playCount: 5),
      Track(id: '2', file: '2.mp3', title: 'apple', artist: 'Bob', album: 'Fruit', addedAt: t0.add(const Duration(days: 1))),
    ];
    expect(filterTracks(tracks).map((t) => t.id), ['2', '1']);
    expect(filterTracks(tracks, sort: TrackSort.mostPlayed).first.id, '1');
    expect(filterTracks(tracks, sort: TrackSort.recentlyAdded).first.id, '2');
    expect(filterTracks(tracks, query: 'fruit').single.id, '2');
    expect(filterTracks(tracks, query: 'ANN').single.id, '1');
    expect(formatTrackTime(const Duration(seconds: 65)), '1:05');
    expect(formatTrackTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  group('library and controller', () {
    late Directory tmp;
    late ProviderContainer c;
    late FakeEngine engine;

    setUp(() async {
      FakeEngine.instances = 0;
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('prism_music');
      await Directory(p.join(tmp.path, 'lib', 'files')).create(recursive: true);
      await Directory(p.join(tmp.path, 'lib', 'art')).create(recursive: true);
      engine = FakeEngine();
      c = ProviderContainer(
        overrides: [
          musicDirProvider.overrideWith((ref) async => Directory(p.join(tmp.path, 'lib'))),
          audioEngineProvider.overrideWithValue(engine),
          mediaControlsProvider.overrideWithValue(MediaControlsPlatform(supported: false)),
          tagReaderProvider.overrideWithValue(
            (f) => (title: null, artist: 'Tagged', album: 'LP', durationMs: 1000, art: null, artMime: null),
          ),
        ],
      );
    });

    tearDown(() async {
      c.dispose();
      await tmp.delete(recursive: true);
    });

    Future<List<String>> importThree() async {
      final paths = <String>[];
      for (final n in ['One_Song.mp3', 'two.m4a', 'three.ogg']) {
        final f = File(p.join(tmp.path, n));
        await f.writeAsBytes([1, 2, 3]);
        paths.add(f.path);
      }
      final r = await c.read(musicLibraryProvider.notifier).importFiles(paths);
      return [for (final t in r.added) t.id];
    }

    test('import copies files, reads tags and reports bad files clearly', () async {
      final empty = File(p.join(tmp.path, 'empty.mp3'))..writeAsBytesSync([]);
      final doc = File(p.join(tmp.path, 'notes.pdf'))..writeAsBytesSync([1]);
      final ok = File(p.join(tmp.path, 'My_Song.mp3'))..writeAsBytesSync([1, 2]);
      await c.read(musicLibraryProvider.future);
      final r = await c.read(musicLibraryProvider.notifier).importFiles([ok.path, doc.path, empty.path, '/nope/missing.wav']);
      expect(r.added.single.title, 'My Song');
      expect(r.added.single.artist, 'Tagged');
      expect(r.unsupported, ['notes.pdf']);
      expect(r.failed, ['empty.mp3', 'missing.wav']);
      expect(File(p.join(tmp.path, 'lib', 'files', r.added.single.file)).existsSync(), isTrue);
      // Persisted: a fresh container sees the same library.
      final c2 = ProviderContainer(overrides: [musicDirProvider.overrideWith((ref) async => Directory(p.join(tmp.path, 'lib')))]);
      addTearDown(c2.dispose);
      expect((await c2.read(musicLibraryProvider.future)).tracks.single.title, 'My Song');
    });

    test('playlists, favorites and delete', () async {
      final ids = await importThree();
      final n = c.read(musicLibraryProvider.notifier);
      final pl = await n.createPlaylist(' Chill ', trackIds: [ids[0]]);
      await n.addToPlaylist(pl.id, ids[1]);
      await n.addToPlaylist(pl.id, ids[1]);
      await n.toggleFavorite(ids[2]);
      await n.createPlaylist('Second');
      await n.reorderPlaylists(1, 0);
      await n.deleteTrack(ids[0]);
      final lib = c.read(musicLibraryProvider).value!;
      expect(lib.playlists.map((x) => x.name), ['Second', 'Chill']);
      expect(lib.playlists[1].trackIds, [ids[1]]);
      expect(lib.tracks.where((t) => t.favorite).single.id, ids[2]);
      expect(lib.tracks.length, 2);
    });

    test('one engine plays the queue, auto-advances and remembers the session', () async {
      final ids = await importThree();
      final ctl = c.read(musicControllerProvider.notifier);
      await ctl.playTracks(ids, start: 1, name: 'All');
      await _settle();
      expect(engine.loads.length, 1);
      expect(c.read(musicControllerProvider).playing, isTrue);
      expect(c.read(musicControllerProvider).currentId, ids[1]);
      engine.finishTrack();
      await _settle();
      expect(c.read(musicControllerProvider).currentId, ids[2]);
      engine.finishTrack();
      await _settle();
      expect(c.read(musicControllerProvider).playing, isFalse, reason: 'stops at the end with repeat off');
      await ctl.jumpTo(0);
      engine.pos = const Duration(seconds: 42);
      await ctl.pause();
      await ctl.setVolume(0.4);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(c.read(musicLibraryProvider).value!.recent.first, ids[0]);
      expect(FakeEngine.instances, 1);

      // "Restart the app": a new controller restores track and position,
      // paused, without touching the audio engine until play is pressed.
      final engine2 = FakeEngine();
      final c2 = ProviderContainer(
        overrides: [
          musicDirProvider.overrideWith((ref) async => Directory(p.join(tmp.path, 'lib'))),
          audioEngineProvider.overrideWithValue(engine2),
          mediaControlsProvider.overrideWithValue(MediaControlsPlatform(supported: false)),
        ],
      );
      addTearDown(c2.dispose);
      c2.read(musicControllerProvider);
      await _settle();
      final s = c2.read(musicControllerProvider);
      expect(s.currentId, ids[0]);
      expect(s.playing, isFalse);
      expect(s.volume, 0.4);
      expect(engine2.loads, isEmpty);
      await c2.read(musicControllerProvider.notifier).play();
      await _settle();
      expect(engine2.pos, const Duration(seconds: 42));
    });

    test('an unplayable file is reported instead of crashing', () async {
      final ids = await importThree();
      engine.failNext = true;
      await c.read(musicControllerProvider.notifier).playTracks(ids);
      expect(c.read(musicControllerProvider).error, isNotNull);
      expect(c.read(musicControllerProvider).playing, isFalse);
    });

    testWidgets('navigating between pages never reloads or restarts the track', (tester) async {
      late List<String> ids;
      await tester.runAsync(() async {
        ids = await importThree();
        await c.read(musicControllerProvider.notifier).playTracks(ids);
        await _settle();
      });
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            navigatorKey: nav,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MusicPlayerHost(child: child!),
            home: const Scaffold(body: Text('page one')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('One Song'), findsOneWidget, reason: 'compact player shows the track');
      for (var i = 0; i < 3; i++) {
        unawaited(nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text('page $i')))));
        await tester.pumpAndSettle();
      }
      nav.currentState!.popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      expect(engine.loads.length, 1);
      expect(engine.isPlaying, isTrue);
      expect(FakeEngine.instances, 1);
      expect(find.text('One Song'), findsOneWidget);
      // Minimizing keeps playing.
      await tester.tap(find.bySemanticsLabel('Minimize player'));
      await tester.pump();
      expect(find.text('One Song'), findsNothing);
      expect(engine.isPlaying, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
