import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/features/accessibility/a11y_settings.dart';
import 'package:prism_plurality/features/music/models/music_models.dart';
import 'package:prism_plurality/features/music/services/music_library.dart';

/// The one audio output for the whole app. Abstract so tests (and
/// platforms without audio) can swap it.
abstract class AudioEngine {
  /// Loads a file; returns its duration when known.
  Future<Duration?> load(String path, {Duration position = Duration.zero});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Duration get position;
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  /// Fires when the loaded track reaches its end.
  Stream<void> get completedStream;
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    unawaited(_configure());
  }

  final _player = AudioPlayer();

  Future<void> _configure() async {
    try {
      // Music category: pauses for calls, ducks for navigation prompts.
      await (await AudioSession.instance).configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  @override
  Future<Duration?> load(String path, {Duration position = Duration.zero}) =>
      _player.setFilePath(path, initialPosition: position == Duration.zero ? null : position);
  @override
  Future<void> play() async => unawaited(_player.play());
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Duration get position => _player.position;
  @override
  Stream<Duration> get positionStream => _player.createPositionStream(
    minPeriod: const Duration(milliseconds: 200),
    maxPeriod: const Duration(milliseconds: 500),
  );
  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<void> get completedStream =>
      _player.processingStateStream.where((s) => s == ProcessingState.completed);
  @override
  Future<void> dispose() => _player.dispose();
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Operating-system media controls (Android notification and lock screen).
class MediaControlsPlatform {
  MediaControlsPlatform({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('com.prismplural.prism/music'),
      isSupported = supported ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final MethodChannel _channel;
  final bool isSupported;

  Future<void> update({
    required String title,
    required String artist,
    required String album,
    String? artPath,
    required bool playing,
    required int positionMs,
    required int durationMs,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'artist': artist,
        'album': album,
        'artPath': artPath,
        'playing': playing,
        'positionMs': positionMs,
        'durationMs': durationMs,
      });
    } on PlatformException {
      // Playback keeps working without system controls.
    } on MissingPluginException {
      //
    }
  }

  Future<void> clear() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException {
      //
    } on MissingPluginException {
      //
    }
  }

  void setHandler(Future<void> Function(String action, int? positionMs) onAction) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      await onAction(call.method, args is Map && args['positionMs'] is int ? args['positionMs'] as int : null);
      return null;
    });
  }
}

final mediaControlsProvider = Provider<MediaControlsPlatform>((ref) => MediaControlsPlatform());

@immutable
class MusicState {
  const MusicState({
    this.queue = const PlayQueue(),
    this.playing = false,
    this.loaded = false,
    this.volume = 1,
    this.durationMs = 0,
    this.error,
    this.look = const PlayerLook(),
  });

  final PlayQueue queue;
  final bool playing;

  /// Whether the current track is loaded in the audio engine.
  final bool loaded;
  final double volume;
  final int durationMs;

  /// File name of a track that could not be played, if the last attempt failed.
  final String? error;
  final PlayerLook look;

  String? get currentId => queue.current;
  bool get hasTrack => queue.current != null;

  MusicState copyWith({
    PlayQueue? queue,
    bool? playing,
    bool? loaded,
    double? volume,
    int? durationMs,
    String? error,
    bool clearError = false,
    PlayerLook? look,
  }) => MusicState(
    queue: queue ?? this.queue,
    playing: playing ?? this.playing,
    loaded: loaded ?? this.loaded,
    volume: volume ?? this.volume,
    durationMs: durationMs ?? this.durationMs,
    error: clearError ? null : (error ?? this.error),
    look: look ?? this.look,
  );
}

const _sessionKey = 'music.session.v1';

/// The single, app-wide playback controller. It lives in a keep-alive
/// provider above the router, so navigation never recreates it and there
/// is only ever one audio engine.
class MusicController extends Notifier<MusicState> {
  late AudioEngine _engine;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _resumeAt = Duration.zero;
  Timer? _persist;
  int _loadToken = 0;
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  MusicState build() {
    _engine = ref.watch(audioEngineProvider);
    _subs.addAll([
      _engine.playingStream.listen((p) {
        if (state.playing != p) {
          state = state.copyWith(playing: p);
          _pushControls();
          _savePosition(force: true);
        }
      }),
      _engine.completedStream.listen((_) => unawaited(_onCompleted())),
      _engine.positionStream.listen((_) => _savePosition()),
    ]);
    ref.read(mediaControlsProvider).setHandler(_onSystemAction);
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _persist?.cancel();
    });
    unawaited(_restore());
    return const MusicState();
  }

  MusicLibrary get _lib => ref.read(musicLibraryProvider).value ?? const MusicLibrary();

  // ------------------------------------------------------------ persistence

  Future<void> _restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_sessionKey);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! Map) return;
      if (!ref.mounted) return;
      final lib = await ref.read(musicLibraryProvider.future);
      if (!ref.mounted) return;
      var q = PlayQueue.fromJson(j['queue']);
      for (final id in q.items.toSet()) {
        if (lib.track(id) == null) q = q.removeTrack(id);
      }
      _resumeAt = Duration(milliseconds: j['positionMs'] is int ? j['positionMs'] as int : 0);
      final volume = (j['volume'] is num ? (j['volume'] as num).toDouble() : 1.0).clamp(0.0, 1.0);
      // Only adopt the saved session if nothing started playing meanwhile.
      if (state.queue.isEmpty) {
        state = state.copyWith(
          queue: q,
          volume: volume,
          look: PlayerLook.fromJson(j['look']),
          durationMs: lib.track(q.current)?.durationMs ?? 0,
        );
      } else {
        state = state.copyWith(look: PlayerLook.fromJson(j['look']));
      }
      await _engine.setVolume(volume);
    } catch (_) {}
  }

  void _saveSoon() {
    _persist?.cancel();
    _persist = Timer(const Duration(milliseconds: 400), () => unawaited(_saveNow()));
  }

  void _savePosition({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastPositionSave) < const Duration(seconds: 5)) return;
    _lastPositionSave = now;
    unawaited(_saveNow());
  }

  Future<void> _saveNow() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _sessionKey,
        jsonEncode({
          'queue': state.queue.toJson(),
          'positionMs': (state.loaded ? _engine.position : _resumeAt).inMilliseconds,
          'volume': state.volume,
          'look': state.look.toJson(),
        }),
      );
    } catch (_) {}
  }

  // ------------------------------------------------------------- playback

  /// Current position (also valid before the restored track is loaded).
  Duration get position => state.loaded ? _engine.position : _resumeAt;

  Stream<Duration> get positionStream => _engine.positionStream;

  Future<bool> _loadCurrent({Duration position = Duration.zero, bool autoplay = true}) async {
    final token = ++_loadToken;
    final track = _lib.track(state.currentId);
    final dir = ref.read(musicDirPathProvider) ?? (await ref.read(musicDirProvider.future)).path;
    if (track == null) return false;
    final path = trackFilePath(dir, track);
    state = state.copyWith(loaded: false, durationMs: track.durationMs, clearError: true);
    try {
      if (!kIsWeb && !File(path).existsSync()) throw const FileSystemException('missing');
      final d = await _engine.load(path, position: position);
      if (token != _loadToken) return false; // a newer request replaced this one
      state = state.copyWith(loaded: true, durationMs: d?.inMilliseconds ?? track.durationMs);
      _resumeAt = Duration.zero;
      if (autoplay) {
        await _engine.play();
        unawaited(ref.read(musicLibraryProvider.notifier).markPlayed(track.id, durationMs: d?.inMilliseconds));
        _announce(track);
      }
      _pushControls();
      _saveSoon();
      return true;
    } catch (_) {
      if (token != _loadToken) return false;
      state = state.copyWith(loaded: false, playing: false, error: track.title);
      return false;
    }
  }

  void _announce(Track t) {
    if (!ref.read(a11ySettingsProvider).announce) return;
    try {
      // Lets screen-reader users know what started without leaving the page.
      unawaited(
        SemanticsService.sendAnnouncement(
          PlatformDispatcher.instance.views.first,
          t.artist.isEmpty ? t.title : '${t.title}, ${t.artist}',
          TextDirection.ltr,
        ),
      );
    } catch (_) {}
  }

  /// Replaces the queue and starts playing at [start].
  Future<void> playTracks(List<String> ids, {int start = 0, String? name}) async {
    if (ids.isEmpty) return;
    state = state.copyWith(queue: state.queue.load(ids, start: start, name: name));
    await _loadCurrent();
  }

  Future<void> play() async {
    if (!state.hasTrack) return;
    if (!state.loaded) {
      await _loadCurrent(position: _resumeAt);
    } else {
      await _engine.play();
    }
  }

  Future<void> pause() async {
    await _engine.pause();
    _savePosition(force: true);
  }

  Future<void> toggle() => state.playing ? pause() : play();

  Future<void> next() async {
    final q = state.queue.next();
    if (q == null) return;
    state = state.copyWith(queue: q);
    await _loadCurrent(autoplay: true);
  }

  Future<void> previous() async {
    // Like most players: restart the track unless it has only just begun.
    if (state.loaded && _engine.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final q = state.queue.previous();
    state = state.copyWith(queue: q);
    await _loadCurrent(autoplay: true);
  }

  Future<void> _onCompleted() async {
    final q = state.queue.next(auto: true);
    if (q == null) {
      await _engine.pause();
      await _engine.seek(Duration.zero);
      state = state.copyWith(playing: false);
      _pushControls();
      return;
    }
    state = state.copyWith(queue: q);
    await _loadCurrent();
  }

  Future<void> seek(Duration position) async {
    if (!state.loaded) {
      _resumeAt = position;
      return;
    }
    await _engine.seek(position);
    _pushControls();
    _savePosition(force: true);
  }

  Future<void> setVolume(double v) async {
    final volume = v.clamp(0.0, 1.0);
    state = state.copyWith(volume: volume);
    await _engine.setVolume(volume);
    _saveSoon();
  }

  void toggleShuffle() {
    state = state.copyWith(queue: state.queue.setShuffle(!state.queue.shuffle));
    _saveSoon();
  }

  void cycleRepeat() {
    state = state.copyWith(queue: state.queue.cycleRepeat());
    _saveSoon();
  }

  Future<void> jumpTo(int index) async {
    state = state.copyWith(queue: state.queue.jumpTo(index));
    await _loadCurrent();
  }

  Future<void> playNext(String id) async {
    final empty = state.queue.isEmpty;
    state = state.copyWith(queue: state.queue.playNext(id));
    if (empty) await _loadCurrent();
    _saveSoon();
  }

  Future<void> addToQueue(String id) async {
    final empty = state.queue.isEmpty;
    state = state.copyWith(queue: state.queue.add(id));
    if (empty) await _loadCurrent();
    _saveSoon();
  }

  Future<void> removeFromQueue(int index) async {
    final wasCurrent = index == state.queue.index;
    final wasPlaying = state.playing;
    state = state.copyWith(queue: state.queue.removeAt(index));
    if (state.queue.isEmpty) return stop();
    if (wasCurrent) await _loadCurrent(autoplay: wasPlaying);
    _saveSoon();
  }

  void moveInQueue(int from, int to) {
    state = state.copyWith(queue: state.queue.move(from, to));
    _saveSoon();
  }

  /// Called when a track is deleted from the library.
  Future<void> forgetTrack(String id) async {
    final wasCurrent = state.currentId == id;
    final wasPlaying = state.playing;
    state = state.copyWith(queue: state.queue.removeTrack(id));
    if (state.queue.isEmpty) return stop();
    if (wasCurrent) await _loadCurrent(autoplay: wasPlaying);
    _saveSoon();
  }

  /// Stops playback and clears the queue (the library is untouched).
  Future<void> stop() async {
    _loadToken++;
    await _engine.stop();
    _resumeAt = Duration.zero;
    state = MusicState(
      queue: PlayQueue(shuffle: state.queue.shuffle, repeat: state.queue.repeat),
      volume: state.volume,
      look: state.look,
    );
    await ref.read(mediaControlsProvider).clear();
    await _saveNow();
  }

  void setLook(PlayerLook look) {
    state = state.copyWith(look: look);
    _saveSoon();
  }

  // ------------------------------------------------------- system controls

  void _pushControls() {
    final t = _lib.track(state.currentId);
    if (t == null) return;
    unawaited(
      ref.read(mediaControlsProvider).update(
        title: t.title,
        artist: t.artist,
        album: t.album,
        artPath: trackArtPath(ref.read(musicDirPathProvider), t),
        playing: state.playing,
        positionMs: position.inMilliseconds,
        durationMs: state.durationMs,
      ),
    );
  }

  Future<void> _onSystemAction(String action, int? positionMs) async {
    switch (action) {
      case 'play':
        await play();
      case 'pause':
        await pause();
      case 'toggle':
        await toggle();
      case 'next':
        await next();
      case 'previous':
        await previous();
      case 'seek':
        if (positionMs != null) await seek(Duration(milliseconds: positionMs));
      case 'stop':
        await stop();
    }
  }
}

final musicControllerProvider = NotifierProvider<MusicController, MusicState>(MusicController.new);

/// Playback position for progress bars. Separate from [MusicState] so the
/// rest of the UI does not rebuild several times a second.
final musicPositionProvider = StreamProvider<Duration>((ref) {
  ref.watch(musicControllerProvider.select((s) => s.currentId));
  ref.watch(musicControllerProvider.select((s) => s.loaded));
  final c = ref.read(musicControllerProvider.notifier);
  return (() async* {
    yield c.position;
    yield* c.positionStream;
  })();
});

final currentTrackProvider = Provider<Track?>((ref) {
  final id = ref.watch(musicControllerProvider.select((s) => s.currentId));
  return ref.watch(musicLibraryProvider).value?.track(id);
});
