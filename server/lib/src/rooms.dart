import 'dart:convert';
import 'dart:math';

import 'package:prism_social_core/prism_social_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'server.dart' show hashToken;
import 'storage.dart' show newId;

/// Online game rooms. Rooms are short-lived and kept in memory: they vanish
/// after two hours without activity (or when the server restarts). No
/// account is needed — each player gets a private token for their seat.
class _Player {
  _Player(this.id, this.name, this.tokenHash) : lastSeen = DateTime.now();
  final String id;
  final String name;
  final String tokenHash;
  DateTime lastSeen;
  bool left = false;
}

class _Room {
  _Room(this.code, this.game, this.hostId) : updated = DateTime.now();
  final String code;
  final OnlineGame game;
  final String hostId;
  final players = <_Player>[];
  String status = 'lobby'; // lobby | playing | finished
  Map<String, Object?> state = const {};
  int version = 1;
  int round = 0;
  final wins = <String, int>{};
  DateTime updated;
  final chat = <Map<String, Object?>>[];

  void bump() {
    version++;
    updated = DateTime.now();
  }

  Map<String, Object?> viewFor(_Player? me) {
    final seat = me == null ? -1 : players.indexOf(me);
    return {
      'code': code,
      'game': game.id,
      'status': status,
      'version': version,
      'round': round,
      'host': hostId,
      'you': me?.id,
      'seat': seat,
      'players': [
        for (final p in players)
          {
            'id': p.id,
            'name': p.name,
            'left': p.left,
            'online': DateTime.now().difference(p.lastSeen).inSeconds < 20,
            'wins': wins[p.id] ?? 0,
          },
      ],
      'state': status == 'lobby'
          ? null
          : (seat >= 0 ? game.viewFor(state, seat) : state),
      'chat': chat.length > 30 ? chat.sublist(chat.length - 30) : chat,
      'minPlayers': game.minPlayers,
      'maxPlayers': game.maxPlayers,
    };
  }
}

class RoomRoutes {
  RoomRoutes({
    required this.clientIp,
    required this.json,
    required this.error,
    required this.body,
    this.maxRooms = 2000,
  });

  final String Function(Request) clientIp;
  final Response Function(Object? body, {int status}) json;
  final Response Function(int status, String code, [String? message]) error;
  final Future<Map<String, Object?>> Function(Request req) body;
  final int maxRooms;
  final _rooms = <String, _Room>{};
  final _creates = <String, List<DateTime>>{};
  final _rand = Random.secure();

  void mount(Router r) {
    r
      ..get(
        '/v1/games',
        (Request _) => json({
          'games': [
            for (final g in onlineGames)
              {
                'id': g.id,
                'name': g.name,
                'emoji': g.emoji,
                'blurb': g.blurb,
                'minPlayers': g.minPlayers,
                'maxPlayers': g.maxPlayers,
              },
          ],
        }),
      )
      ..post('/v1/rooms', _create)
      ..post('/v1/rooms/<code>/join', _join)
      ..get('/v1/rooms/<code>', _get)
      ..post('/v1/rooms/<code>/start', _start)
      ..post('/v1/rooms/<code>/move', _move)
      ..post('/v1/rooms/<code>/chat', _chat)
      ..post('/v1/rooms/<code>/leave', _leave);
  }

  void _sweep() {
    final now = DateTime.now();
    _rooms.removeWhere(
      (_, r) => now.difference(r.updated) > const Duration(hours: 2),
    );
  }

  String _newCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (;;) {
      final c = List.generate(
        5,
        (_) => letters[_rand.nextInt(letters.length)],
      ).join();
      if (!_rooms.containsKey(c)) return c;
    }
  }

  String _name(Map<String, Object?> b) {
    final n = '${b['name'] ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ');
    return n.isEmpty ? 'Player' : (n.length > 24 ? n.substring(0, 24) : n);
  }

  (_Room, _Player?)? _find(Request req, String code) {
    final room = _rooms[code.toUpperCase()];
    if (room == null) return null;
    final token = req.headers['x-player-token'] ?? '';
    final h = token.isEmpty ? null : hashToken(token);
    final me = room.players.where((p) => p.tokenHash == h).firstOrNull;
    me?.lastSeen = DateTime.now();
    return (room, me);
  }

  Future<Response> _create(Request req) async {
    _sweep();
    final ip = clientIp(req);
    final now = DateTime.now();
    final hits = _creates.putIfAbsent(ip, () => [])
      ..removeWhere((t) => now.difference(t).inMinutes >= 10);
    if (hits.length >= 20 || _rooms.length >= maxRooms)
      return error(429, 'rate_limited');
    hits.add(now);
    final b = await body(req);
    final game = onlineGameById('${b['game'] ?? ''}');
    if (game == null) return error(400, 'unknown_game');
    final token = newId(24);
    final p = _Player(newId(6), _name(b), hashToken(token));
    final room = _Room(_newCode(), game, p.id)..players.add(p);
    _rooms[room.code] = room;
    return json({'token': token, 'room': room.viewFor(p)}, status: 201);
  }

  Future<Response> _join(Request req, String code) async {
    final f = _find(req, code);
    if (f == null) return error(404, 'not_found', 'No room with that code.');
    final (room, existing) = f;
    if (existing != null) return json({'room': room.viewFor(existing)});
    if (room.status != 'lobby')
      return error(409, 'in_progress', 'That game has already started.');
    if (room.players.length >= room.game.maxPlayers)
      return error(409, 'room_full', 'That room is full.');
    final token = newId(24);
    final p = _Player(newId(6), _name(await body(req)), hashToken(token));
    room
      ..players.add(p)
      ..bump();
    return json({'token': token, 'room': room.viewFor(p)});
  }

  Future<Response> _get(Request req, String code) async {
    final f = _find(req, code);
    if (f == null) return error(404, 'not_found', 'This room has closed.');
    final (room, me) = f;
    if (req.url.queryParameters['v'] == '${room.version}') return Response(304);
    return json({'room': room.viewFor(me)});
  }

  Future<Response> _start(Request req, String code) async {
    final f = _find(req, code);
    if (f == null) return error(404, 'not_found');
    final (room, me) = f;
    if (me == null) return error(403, 'not_in_room');
    if (me.id != room.hostId)
      return error(403, 'host_only', 'Only the host can start.');
    room.players.removeWhere((p) => p.left);
    if (room.players.length < room.game.minPlayers)
      return error(409, 'need_players', 'Waiting for more players.');
    // Rematch: rotate who goes first.
    if (room.round > 0) room.players.add(room.players.removeAt(0));
    room
      ..state = room.game.initial(room.players.length)
      ..status = 'playing'
      ..round = room.round + 1
      ..bump();
    return json({'room': room.viewFor(me)});
  }

  Future<Response> _move(Request req, String code) async {
    final f = _find(req, code);
    if (f == null) return error(404, 'not_found');
    final (room, me) = f;
    if (me == null) return error(403, 'not_in_room');
    if (room.status != 'playing') return error(409, 'not_playing');
    final b = await body(req);
    try {
      room.state = room.game.apply(
        room.state,
        room.players.indexOf(me),
        b['move'],
      );
    } on GameMoveError catch (e) {
      return error(409, e.code);
    }
    if (room.game.finished(room.state)) {
      room.status = 'finished';
      for (final w in room.game.winners(room.state)) {
        final id = room.players[w].id;
        room.wins[id] = (room.wins[id] ?? 0) + 1;
      }
    }
    room.bump();
    return json({'room': room.viewFor(me)});
  }

  Future<Response> _chat(Request req, String code) async {
    final f = _find(req, code);
    if (f == null) return error(404, 'not_found');
    final (room, me) = f;
    if (me == null) return error(403, 'not_in_room');
    final text = '${(await body(req))['text'] ?? ''}'.trim();
    if (text.isEmpty) return error(400, 'empty');
    room.chat.add({
      'from': me.id,
      'text': text.length > 200 ? text.substring(0, 200) : text,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    if (room.chat.length > 60) room.chat.removeRange(0, room.chat.length - 60);
    room.bump();
    return json({'room': room.viewFor(me)});
  }

  Future<Response> _leave(Request req, String code) async {
    final f = _find(req, code);
    if (f == null) return json({'ok': true});
    final (room, me) = f;
    if (me == null) return json({'ok': true});
    if (room.status == 'lobby') {
      room.players.remove(me);
    } else {
      me.left = true;
      // Leaving mid-game ends it for a two-player game.
      if (room.status == 'playing' &&
          room.players.where((p) => !p.left).length < room.game.minPlayers)
        room.status = 'finished';
    }
    if (room.players.every((p) => p.left)) {
      _rooms.remove(room.code);
    } else {
      room.bump();
    }
    return json({'ok': true});
  }

  /// For tests.
  int get roomCount => _rooms.length;
  String debugJson(String code) => jsonEncode(_rooms[code]?.state);
}
