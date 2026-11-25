import 'package:flutter/foundation.dart';

/// Audio formats Prism offers in the file picker. Whether a given file
/// actually plays depends on the device's decoders.
const supportedAudioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'flac'];

@immutable
class Track {
  const Track({
    required this.id,
    required this.file,
    required this.title,
    this.artist = '',
    this.album = '',
    this.durationMs = 0,
    this.art,
    required this.addedAt,
    this.favorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
  });

  final String id;

  /// File name inside the music folder (Prism keeps its own copy).
  final String file;
  final String title;
  final String artist;
  final String album;
  final int durationMs;

  /// Cover art file name inside the art folder, when the file had one.
  final String? art;
  final DateTime addedAt;
  final bool favorite;
  final int playCount;
  final DateTime? lastPlayedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? art,
    bool clearArt = false,
    bool? favorite,
    int? playCount,
    DateTime? lastPlayedAt,
  }) => Track(
    id: id,
    file: file,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    durationMs: durationMs ?? this.durationMs,
    art: clearArt ? null : (art ?? this.art),
    addedAt: addedAt,
    favorite: favorite ?? this.favorite,
    playCount: playCount ?? this.playCount,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'file': file,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'art': art,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'favorite': favorite,
    'playCount': playCount,
    'lastPlayedAt': lastPlayedAt?.millisecondsSinceEpoch,
  };

  static Track? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['file'] is! String) return null;
    return Track(
      id: j['id'] as String,
      file: j['file'] as String,
      title: j['title'] is String ? j['title'] as String : '',
      artist: j['artist'] is String ? j['artist'] as String : '',
      album: j['album'] is String ? j['album'] as String : '',
      durationMs: j['durationMs'] is int ? j['durationMs'] as int : 0,
      art: j['art'] is String ? j['art'] as String : null,
      addedAt: DateTime.fromMillisecondsSinceEpoch(j['addedAt'] is int ? j['addedAt'] as int : 0),
      favorite: j['favorite'] == true,
      playCount: j['playCount'] is int ? j['playCount'] as int : 0,
      lastPlayedAt: j['lastPlayedAt'] is int ? DateTime.fromMillisecondsSinceEpoch(j['lastPlayedAt'] as int) : null,
    );
  }
}

@immutable
class Playlist {
  const Playlist({required this.id, required this.name, this.trackIds = const []});

  final String id;
  final String name;
  final List<String> trackIds;

  Playlist copyWith({String? name, List<String>? trackIds}) =>
      Playlist(id: id, name: name ?? this.name, trackIds: trackIds ?? this.trackIds);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'trackIds': trackIds};

  static Playlist? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    return Playlist(
      id: j['id'] as String,
      name: j['name'] is String ? j['name'] as String : '',
      trackIds: [
        if (j['trackIds'] is List)
          for (final x in j['trackIds'] as List)
            if (x is String) x,
      ],
    );
  }
}

enum TrackSort { title, artist, album, recentlyAdded, mostPlayed }

@immutable
class MusicLibrary {
  const MusicLibrary({this.tracks = const [], this.playlists = const [], this.recent = const [], this.plays = const []});

  final List<Track> tracks;
  final List<Playlist> playlists;

  /// Recently played track ids, newest first.
  final List<String> recent;

  /// Every play Prism itself recorded (track id, when), oldest first, kept
  /// to the last 5,000. Recaps count only these — never guesses.
  final List<(String, DateTime)> plays;

  Track? track(String? id) {
    if (id == null) return null;
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Track> resolve(Iterable<String> ids) => [for (final id in ids) ?track(id)];

  MusicLibrary copyWith({List<Track>? tracks, List<Playlist>? playlists, List<String>? recent, List<(String, DateTime)>? plays}) => MusicLibrary(
    tracks: tracks ?? this.tracks,
    playlists: playlists ?? this.playlists,
    recent: recent ?? this.recent,
    plays: plays ?? this.plays,
  );

  Map<String, Object?> toJson() => {
    'tracks': [for (final t in tracks) t.toJson()],
    'playlists': [for (final p in playlists) p.toJson()],
    'recent': recent,
    'plays': [for (final (id, at) in plays) [id, at.millisecondsSinceEpoch]],
  };

  static MusicLibrary fromJson(Object? j) {
    if (j is! Map) return const MusicLibrary();
    return MusicLibrary(
      tracks: [
        if (j['tracks'] is List)
          for (final t in j['tracks'] as List) ?Track.fromJson(t),
      ],
      playlists: [
        if (j['playlists'] is List)
          for (final p in j['playlists'] as List) ?Playlist.fromJson(p),
      ],
      recent: [
        if (j['recent'] is List)
          for (final r in j['recent'] as List)
            if (r is String) r,
      ],
      plays: [
        if (j['plays'] is List)
          for (final p in j['plays'] as List)
            if (p is List && p.length == 2 && p[0] is String && p[1] is num) (p[0] as String, DateTime.fromMillisecondsSinceEpoch((p[1] as num).toInt())),
      ],
    );
  }
}

/// Search (title, artist, album) and sort.
List<Track> filterTracks(Iterable<Track> tracks, {String query = '', TrackSort sort = TrackSort.title}) {
  final q = query.trim().toLowerCase();
  final list = [
    for (final t in tracks)
      if (q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q))
        t,
  ];
  int text(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  list.sort(switch (sort) {
    TrackSort.title => (a, b) => text(a.title, b.title),
    TrackSort.artist => (a, b) => text(a.artist, b.artist) != 0 ? text(a.artist, b.artist) : text(a.title, b.title),
    TrackSort.album => (a, b) => text(a.album, b.album) != 0 ? text(a.album, b.album) : text(a.title, b.title),
    TrackSort.recentlyAdded => (a, b) => b.addedAt.compareTo(a.addedAt),
    TrackSort.mostPlayed => (a, b) => b.playCount.compareTo(a.playCount),
  });
  return list;
}

String formatTrackTime(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:${sec.toString().padLeft(2, '0')}';
}

enum RepeatMode { off, all, one }

enum PlayerLayout { bar, bubble, hidden }

enum PlayerPlacement { bottom, top }

/// How the app-wide player looks (device setting).
@immutable
class PlayerLook {
  const PlayerLook({
    this.layout = PlayerLayout.bar,
    this.placement = PlayerPlacement.bottom,
    this.artworkBackground = true,
    this.blurArtwork = true,
    this.color,
    this.bubbleX = 1,
    this.bubbleY = 0.7,
  });

  final PlayerLayout layout;
  final PlayerPlacement placement;
  final bool artworkBackground;
  final bool blurArtwork;

  /// Custom player colour (ARGB); null follows the app theme.
  final int? color;

  /// Floating bubble position as fractions of the screen.
  final double bubbleX;
  final double bubbleY;

  PlayerLook copyWith({
    PlayerLayout? layout,
    PlayerPlacement? placement,
    bool? artworkBackground,
    bool? blurArtwork,
    int? color,
    bool clearColor = false,
    double? bubbleX,
    double? bubbleY,
  }) => PlayerLook(
    layout: layout ?? this.layout,
    placement: placement ?? this.placement,
    artworkBackground: artworkBackground ?? this.artworkBackground,
    blurArtwork: blurArtwork ?? this.blurArtwork,
    color: clearColor ? null : (color ?? this.color),
    bubbleX: bubbleX ?? this.bubbleX,
    bubbleY: bubbleY ?? this.bubbleY,
  );

  Map<String, Object?> toJson() => {
    'layout': layout.name,
    'placement': placement.name,
    'artworkBackground': artworkBackground,
    'blurArtwork': blurArtwork,
    'color': color,
    'bubbleX': bubbleX,
    'bubbleY': bubbleY,
  };

  static PlayerLook fromJson(Object? j) {
    if (j is! Map) return const PlayerLook();
    double f(Object? v, double d) => (v is num ? v.toDouble() : d).clamp(0, 1).toDouble();
    return PlayerLook(
      layout: PlayerLayout.values.firstWhere((x) => x.name == j['layout'], orElse: () => PlayerLayout.bar),
      placement: PlayerPlacement.values.firstWhere((x) => x.name == j['placement'], orElse: () => PlayerPlacement.bottom),
      artworkBackground: j['artworkBackground'] != false,
      blurArtwork: j['blurArtwork'] != false,
      color: j['color'] is int ? j['color'] as int : null,
      bubbleX: f(j['bubbleX'], 1),
      bubbleY: f(j['bubbleY'], 0.7),
    );
  }
}

/// The play queue: pure logic, no audio. [items] is the play order;
/// [original] is the order before shuffling so it can be restored.
@immutable
class PlayQueue {
  const PlayQueue({this.items = const [], this.original = const [], this.index = 0, this.shuffle = false, this.repeat = RepeatMode.off, this.name});

  final List<String> items;
  final List<String> original;
  final int index;
  final bool shuffle;
  final RepeatMode repeat;

  /// Where the queue came from (playlist name, "Favorites" …).
  final String? name;

  String? get current => index >= 0 && index < items.length ? items[index] : null;
  bool get isEmpty => items.isEmpty;

  PlayQueue _with({List<String>? items, List<String>? original, int? index, bool? shuffle, RepeatMode? repeat, String? name}) => PlayQueue(
    items: items ?? this.items,
    original: original ?? this.original,
    index: index ?? this.index,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    name: name ?? this.name,
  );

  /// Starts a new queue at [start], keeping shuffle/repeat settings.
  PlayQueue load(List<String> ids, {int start = 0, String? name, List<String> Function(List<String>)? shuffler}) {
    if (ids.isEmpty) return PlayQueue(shuffle: shuffle, repeat: repeat);
    final s = start.clamp(0, ids.length - 1);
    if (!shuffle) return PlayQueue(items: ids, original: ids, index: s, shuffle: false, repeat: repeat, name: name);
    final rest = [...ids]..removeAt(s);
    final mixed = (shuffler ?? _shuffle)(rest);
    return PlayQueue(items: [ids[s], ...mixed], original: ids, index: 0, shuffle: true, repeat: repeat, name: name);
  }

  static List<String> _shuffle(List<String> l) => [...l]..shuffle();

  PlayQueue setShuffle(bool on, {List<String> Function(List<String>)? shuffler}) {
    if (on == shuffle) return this;
    final cur = current;
    if (cur == null) return _with(shuffle: on);
    if (on) {
      final rest = [...items]..removeAt(index);
      return _with(items: [cur, ...(shuffler ?? _shuffle)(rest)], original: items, index: 0, shuffle: true);
    }
    // Back to the original order, staying on the current track.
    final restored = [for (final id in original) if (items.contains(id)) id, for (final id in items) if (!original.contains(id)) id];
    final i = restored.indexOf(cur);
    return _with(items: restored, original: restored, index: i < 0 ? 0 : i, shuffle: false);
  }

  PlayQueue setRepeat(RepeatMode mode) => _with(repeat: mode);

  PlayQueue cycleRepeat() => setRepeat(RepeatMode.values[(repeat.index + 1) % RepeatMode.values.length]);

  /// The queue after the current track finishes or the user skips.
  /// Returns null when playback should stop (end of queue, repeat off).
  PlayQueue? next({bool auto = false}) {
    if (items.isEmpty) return null;
    if (auto && repeat == RepeatMode.one) return this;
    if (index + 1 < items.length) return _with(index: index + 1);
    if (repeat == RepeatMode.all || (!auto && repeat == RepeatMode.one)) return _with(index: 0);
    return null;
  }

  PlayQueue previous() {
    if (items.isEmpty) return this;
    if (index > 0) return _with(index: index - 1);
    return repeat == RepeatMode.all ? _with(index: items.length - 1) : this;
  }

  PlayQueue jumpTo(int i) => i < 0 || i >= items.length ? this : _with(index: i);

  /// Inserts [id] right after the current track.
  PlayQueue playNext(String id) {
    if (items.isEmpty) return load([id]);
    final next = [...items]..insert(index + 1, id);
    return _with(items: next, original: [...original, id]);
  }

  PlayQueue add(String id) => items.isEmpty ? load([id]) : _with(items: [...items, id], original: [...original, id]);

  PlayQueue removeAt(int i) {
    if (i < 0 || i >= items.length) return this;
    final next = [...items]..removeAt(i);
    final o = [...original];
    final oi = o.indexOf(items[i]);
    if (oi >= 0) o.removeAt(oi);
    var idx = index;
    if (i < index) idx--;
    if (idx >= next.length) idx = next.isEmpty ? 0 : next.length - 1;
    return _with(items: next, original: o, index: idx);
  }

  /// Drops every occurrence of [id] (the track was deleted).
  PlayQueue removeTrack(String id) {
    var q = this;
    for (var i = q.items.length - 1; i >= 0; i--) {
      if (q.items[i] == id) q = q.removeAt(i);
    }
    return q;
  }

  PlayQueue move(int from, int to) {
    if (from < 0 || from >= items.length) return this;
    final next = [...items];
    final id = next.removeAt(from);
    final t = to.clamp(0, next.length);
    next.insert(t, id);
    var idx = index;
    if (from == index) {
      idx = t;
    } else {
      if (from < index) idx--;
      if (t <= idx) idx++;
    }
    return _with(items: next, index: idx);
  }

  Map<String, Object?> toJson() => {
    'items': items,
    'original': original,
    'index': index,
    'shuffle': shuffle,
    'repeat': repeat.name,
    'name': name,
  };

  static PlayQueue fromJson(Object? j) {
    if (j is! Map) return const PlayQueue();
    List<String> l(Object? v) => [if (v is List) for (final x in v) if (x is String) x];
    final items = l(j['items']);
    final index = j['index'] is int ? j['index'] as int : 0;
    return PlayQueue(
      items: items,
      original: l(j['original']).isEmpty ? items : l(j['original']),
      index: items.isEmpty ? 0 : index.clamp(0, items.length - 1),
      shuffle: j['shuffle'] == true,
      repeat: RepeatMode.values.firstWhere((x) => x.name == j['repeat'], orElse: () => RepeatMode.off),
      name: j['name'] is String ? j['name'] as String : null,
    );
  }
}
