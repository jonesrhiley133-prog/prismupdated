import 'dart:convert';

import 'package:prism_social_server/prism_social_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler h;
  setUp(() => h = PrismSocialServer(MemoryStorage()).handler);

  Future<(int, Map<String, Object?>)> call(String method, String path, {Object? body, String? token}) async {
    final res = await h(Request(method, Uri.parse('http://localhost$path'), body: body == null ? null : jsonEncode(body), headers: {'x-player-token': ?token}));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty ? <String, Object?>{} : (jsonDecode(text) as Map).cast<String, Object?>());
  }

  test('create, join, play tic-tac-toe, rematch', () async {
    var (code, b) = await call('POST', '/v1/rooms', body: {'game': 'tictactoe', 'name': 'Ash'});
    expect(code, 201);
    final hostToken = b['token'] as String;
    final roomCode = (b['room']! as Map)['code'] as String;

    (code, b) = await call('POST', '/v1/rooms/$roomCode/start', token: hostToken);
    expect(code, 409); // need 2 players

    (code, b) = await call('POST', '/v1/rooms/${roomCode.toLowerCase()}/join', body: {'name': 'Bea'});
    final guestToken = b['token'] as String;
    expect(((b['room']! as Map)['players'] as List).length, 2);

    (code, b) = await call('POST', '/v1/rooms/$roomCode/start', token: guestToken);
    expect(code, 403);
    (code, b) = await call('POST', '/v1/rooms/$roomCode/start', token: hostToken);
    expect((b['room']! as Map)['status'], 'playing');

    (code, b) = await call('POST', '/v1/rooms/$roomCode/move', token: guestToken, body: {'move': 4});
    expect(code, 409);
    for (final (t, m) in [(hostToken, 0), (guestToken, 3), (hostToken, 1), (guestToken, 4), (hostToken, 2)]) {
      (code, b) = await call('POST', '/v1/rooms/$roomCode/move', token: t, body: {'move': m});
      expect(code, 200);
    }
    final room = b['room']! as Map;
    expect(room['status'], 'finished');
    expect(((room['players'] as List).first as Map)['wins'], 1);

    final v = room['version'];
    (code, _) = await call('GET', '/v1/rooms/$roomCode?v=$v', token: guestToken);
    expect(code, 304);

    (code, b) = await call('POST', '/v1/rooms/$roomCode/start', token: hostToken);
    expect((b['room']! as Map)['round'], 2);
    expect((b['room']! as Map)['seat'], 1); // host now goes second
  });

  test('secret picks stay hidden from the other player', () async {
    var (_, b) = await call('POST', '/v1/rooms', body: {'game': 'rps', 'name': 'A'});
    final a = b['token'] as String;
    final code = (b['room']! as Map)['code'];
    (_, b) = await call('POST', '/v1/rooms/$code/join', body: {'name': 'B'});
    final bt = b['token'] as String;
    await call('POST', '/v1/rooms/$code/start', token: a);
    await call('POST', '/v1/rooms/$code/move', token: a, body: {'move': 'rock'});
    (_, b) = await call('GET', '/v1/rooms/$code', token: bt);
    expect(((b['room']! as Map)['state'] as Map)['picks'], ['hidden', null]);
  });

  test('full rooms and unknown codes', () async {
    var (_, b) = await call('POST', '/v1/rooms', body: {'game': 'connect4'});
    final code = (b['room']! as Map)['code'];
    await call('POST', '/v1/rooms/$code/join', body: {});
    var (status, _) = await call('POST', '/v1/rooms/$code/join', body: {});
    expect(status, 409);
    (status, _) = await call('GET', '/v1/rooms/ZZZZZ');
    expect(status, 404);
  });
}
