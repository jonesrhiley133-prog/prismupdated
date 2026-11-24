import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as hp;
import 'package:prism_social_core/prism_social_core.dart';

import 'package:prism_plurality/features/prism_social/social_remote.dart'
    show normalizeServerUrl;

class RoomError implements Exception {
  const RoomError(this.code, [this.message]);
  final String code;
  final String? message;
  @override
  String toString() =>
      message ??
      switch (code) {
        'not_your_turn' => "It's not your turn.",
        'bad_cell' || 'bad_column' || 'column_full' => "You can't play there.",
        'already_picked' => 'You already picked.',
        'game_over' => 'This game is over.',
        'offline' => "Couldn't reach the server.",
        _ => 'Something went wrong ($code).',
      };
}

/// A snapshot of a room as the server sent it.
@immutable
class RoomView {
  const RoomView(this.j);
  final Map<String, Object?> j;
  String get code => j['code']! as String;
  OnlineGame get game =>
      onlineGameById(j['game']! as String) ?? const TicTacToe();
  String get status => j['status']! as String;
  int get version => (j['version']! as num).toInt();
  int get round => (j['round'] as num?)?.toInt() ?? 0;
  String? get you => j['you'] as String?;
  int get seat => (j['seat'] as num?)?.toInt() ?? -1;
  bool get isHost => you != null && j['host'] == you;
  List<Map<String, Object?>> get players => [
    for (final p in (j['players'] as List? ?? const []))
      (p as Map).cast<String, Object?>(),
  ];
  Map<String, Object?>? get state =>
      (j['state'] as Map?)?.cast<String, Object?>();
  List<Map<String, Object?>> get chat => [
    for (final c in (j['chat'] as List? ?? const []))
      (c as Map).cast<String, Object?>(),
  ];
  int? get turn => state == null ? null : game.turn(state!);
  bool get myTurn => status == 'playing' && turn == seat;
  List<int> get winners => state == null ? const [] : game.winners(state!);
  String nameOf(int seatIndex) => seatIndex >= 0 && seatIndex < players.length
      ? '${players[seatIndex]['name']}'
      : '?';
  String nameById(String? id) =>
      '${players.where((p) => p['id'] == id).firstOrNull?['name'] ?? '?'}';
}

class RoomClient {
  RoomClient(this.server, {this.token, hp.Client? http})
    : _http = http ?? hp.Client();
  final String server;
  String? token;
  final hp.Client _http;

  Uri _u(String p) => Uri.parse('${normalizeServerUrl(server)}$p');

  Future<Map<String, Object?>?> _call(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    hp.Response r;
    try {
      final headers = {
        'content-type': 'application/json',
        if (token != null) 'x-player-token': token!,
      };
      r =
          await (method == 'GET'
                  ? _http.get(_u(path), headers: headers)
                  : _http.post(
                      _u(path),
                      headers: headers,
                      body: jsonEncode(body ?? const {}),
                    ))
              .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const RoomError('offline');
    }
    if (r.statusCode == 304) return null;
    Map<String, Object?> m = const {};
    try {
      m = (jsonDecode(r.body) as Map).cast<String, Object?>();
    } catch (_) {}
    if (r.statusCode >= 400) {
      final e = m['error'];
      throw RoomError(
        e is Map ? '${e['code']}' : 'http_${r.statusCode}',
        e is Map ? e['message'] as String? : null,
      );
    }
    return m;
  }

  Future<RoomView> create(String game, String name) async {
    final m = (await _call('POST', '/v1/rooms', {'game': game, 'name': name}))!;
    token = m['token'] as String?;
    return RoomView((m['room']! as Map).cast());
  }

  Future<RoomView> join(String code, String name) async {
    final m = (await _call(
      'POST',
      '/v1/rooms/${code.trim().toUpperCase()}/join',
      {'name': name},
    ))!;
    token = (m['token'] as String?) ?? token;
    return RoomView((m['room']! as Map).cast());
  }

  Future<RoomView?> fetch(String code, int? version) async {
    final m = await _call(
      'GET',
      '/v1/rooms/$code${version == null ? '' : '?v=$version'}',
    );
    return m == null ? null : RoomView((m['room']! as Map).cast());
  }

  Future<RoomView> act(
    String code,
    String action, [
    Map<String, Object?>? body,
  ]) async => RoomView(
    ((await _call('POST', '/v1/rooms/$code/$action', body))!['room']! as Map)
        .cast(),
  );

  Future<void> leave(String code) async {
    try {
      await _call('POST', '/v1/rooms/$code/leave');
    } catch (_) {}
  }
}

/// A live room: polls the server and sends actions.
class RoomSession extends ChangeNotifier {
  RoomSession(this.client, RoomView first) : room = first {
    _timer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => refresh(),
    );
  }

  final RoomClient client;
  RoomView room;
  String? error;
  bool busy = false;
  bool closed = false;
  Timer? _timer;
  bool _polling = false;

  Future<void> refresh() async {
    if (_polling || closed) return;
    _polling = true;
    try {
      final next = await client.fetch(room.code, room.version);
      if (next != null) {
        room = next;
        error = null;
        notifyListeners();
      }
    } on RoomError catch (e) {
      if (e.code == 'not_found') {
        closed = true;
        error = 'This room has closed.';
        _timer?.cancel();
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _do(String action, [Map<String, Object?>? body]) async {
    busy = true;
    notifyListeners();
    try {
      room = await client.act(room.code, action, body);
      error = null;
    } on RoomError catch (e) {
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> move(Object? move) => _do('move', {'move': move});
  Future<void> start() => _do('start');
  Future<void> say(String text) => _do('chat', {'text': text});

  Future<void> leave() async {
    closed = true;
    _timer?.cancel();
    await client.leave(room.code);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The server online games use (the Social server, by default).
final onlineServerProvider = NotifierProvider<OnlineServerNotifier, String>(
  OnlineServerNotifier.new,
);

class OnlineServerNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String s) => state = s;
}
