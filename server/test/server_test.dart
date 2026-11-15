import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:prism_social_server/prism_social_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Drives the real HTTP handler in-process (no network).
class Client {
  Client(this.handler, [this.token]);
  final Handler handler;
  String? token;

  Future<(int, Object?)> call(String method, String path, {Object? body, Map<String, String> headers = const {}, List<int>? bytes}) async {
    final res = await handler(Request(method, Uri.parse('http://localhost$path'), body: bytes ?? (body == null ? null : jsonEncode(body)), headers: {if (token != null) 'authorization': 'Bearer $token', ...headers}));
    final text = await res.readAsString();
    return (res.statusCode, text.isEmpty || !(res.headers['content-type'] ?? '').contains('json') ? text : jsonDecode(text));
  }

  Future<Object?> rpc(String m, Map<String, Object?> args) async {
    final (code, body) = await call('POST', '/v1/rpc/$m', body: args);
    if (code != 200) throw StateError('$m → $code $body');
    return (body! as Map)['result'];
  }

  Future<String> errorOf(String m, Map<String, Object?> args) async {
    final (code, body) = await call('POST', '/v1/rpc/$m', body: args);
    expect(code, isNot(200));
    return ((body! as Map)['error'] as Map)['code'] as String;
  }

  Future<List<Map<String, Object?>>> sync() async {
    final (code, body) = await call('GET', '/v1/sync');
    expect(code, 200);
    return [for (final r in (body! as Map)['records'] as List) (r as Map).cast<String, Object?>()];
  }

  static Future<Client> register(Handler h) async {
    final c = Client(h);
    final (code, body) = await c.call('POST', '/v1/auth/register');
    expect(code, 201);
    c.token = (body! as Map)['token'] as String;
    return c;
  }
}

void main() {
  // Set PRISM_TEST_DATABASE_URL to run the same suite against Postgres.
  final pgUrl = Platform.environment['PRISM_TEST_DATABASE_URL'];
  late ServerStorage storage;
  late Handler h;

  setUp(() async {
    if (pgUrl != null) {
      final pg = PostgresStorage(pgUrl);
      await pg.init();
      await pg.resetForTests();
      storage = pg;
      addTearDown(pg.close);
    } else {
      storage = MemoryStorage();
    }
    h = PrismSocialServer(storage, config: const ServerConfig(writesPerMinute: 1000)).handler;
  });

  test('health, info and CORS', () async {
    final c = Client(h);
    expect((await c.call('GET', '/healthz')).$1, 200);
    final (_, info) = await c.call('GET', '/v1/info');
    expect((info! as Map)['registration'], 'open');
    final res = await h(Request('OPTIONS', Uri.parse('http://localhost/v1/sync')));
    expect(res.headers['access-control-allow-origin'], '*');
    expect(res.headers['access-control-allow-headers'], contains('authorization'));
  });

  test('auth is required and tokens are stored hashed', () async {
    final anon = Client(h);
    expect((await anon.call('GET', '/v1/sync')).$1, 401);
    expect((await anon.call('POST', '/v1/rpc/touch', body: {'profileId': 'x'})).$1, 401);
    final a = await Client.register(h);
    expect(await storage.accountForTokenHash(a.token!), isNull, reason: 'raw tokens are never stored');
    expect(await storage.accountForTokenHash(hashToken(a.token!)), isNotNull);
    expect((await Client(h, 'x' * 64).call('GET', '/v1/sync')).$1, 401);
  });

  test('two people: friend, message alter-to-alter, post, react, sync', () async {
    final alice = await Client.register(h);
    final bob = await Client.register(h);
    final a = await alice.rpc('createProfile', {'username': 'aurora', 'systemName': 'Aurora'}) as String;
    final b = await bob.rpc('createProfile', {'username': 'birch', 'systemName': 'Birch'}) as String;
    expect(await alice.errorOf('createProfile', {'username': 'birch', 'systemName': 'Copy'}), 'username_taken');
    final mira = await bob.rpc('saveAlter', {'profileId': b, 'name': 'Mira'}) as String;

    // Alice can't act as Bob.
    expect(await alice.errorOf('createPost', {'actor': {'p': b}, 'type': 'text', 'body': 'x'}), 'not_managed');

    await alice.rpc('sendRequest', {'from': {'p': a}, 'to': b, 'note': 'hi!'});
    final reqs = (await bob.sync()).where((r) => r['kind'] == 'soc.request').toList();
    expect(reqs, hasLength(1));
    await bob.rpc('acceptRequest', {'actor': {'p': b}, 'requestId': reqs.single['id']});

    final conv = await alice.rpc('openConversation', {'me': {'p': a}, 'them': {'p': b, 'a': mira}}) as String;
    await alice.rpc('sendMessage', {'actor': {'p': a}, 'conversationId': conv, 'body': 'Hi Mira'});
    await bob.rpc('sendMessage', {'actor': {'p': b, 'a': mira}, 'conversationId': conv, 'body': 'Hi Aurora'});
    final post = await bob.rpc('createPost', {'actor': {'p': b, 'a': mira}, 'type': 'text', 'body': 'Painted today', 'audience': 'everyone'}) as String;
    await alice.rpc('toggleReact', {'actor': {'p': a}, 'postId': post, 'type': 'like'});
    expect(await alice.errorOf('toggleReact', {'actor': {'p': a}, 'postId': post, 'type': 'hug'}), 'bad_request');

    final aliceView = await alice.sync();
    expect(aliceView.where((r) => r['kind'] == 'soc.message'), hasLength(2));
    expect(aliceView.where((r) => r['kind'] == 'soc.alter').single['title'], 'Mira');
    final bobNotifs = (await bob.sync()).where((r) => r['kind'] == 'soc.notif').map((r) => (r['fields']! as Map)['type']).toSet();
    expect(bobNotifs, containsAll(['request', 'alterMessage', 'like']));
    // Owners and tokens never leave the server.
    expect(jsonEncode(aliceView), isNot(contains('owner')));
  });

  test('sync returns 304 when nothing changed', () async {
    final a = await Client.register(h);
    await a.rpc('createProfile', {'username': 'aurora', 'systemName': 'Aurora'});
    final (_, body) = await a.call('GET', '/v1/sync');
    final v = (body! as Map)['version'];
    expect((await a.call('GET', '/v1/sync?v=$v')).$1, 304);
    await a.rpc('touch', {'profileId': (body as Map)['profiles'].first});
    expect((await a.call('GET', '/v1/sync?v=$v')).$1, 200);
  });

  test('media upload, limits and download', () async {
    final a = await Client.register(h);
    final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
    final (code, body) = await a.call('POST', '/v1/media', bytes: png, headers: {'content-type': 'image/png'});
    expect(code, 201);
    final id = (body! as Map)['id'];
    final res = await h(Request('GET', Uri.parse('http://localhost/v1/media/$id'), headers: {'authorization': 'Bearer ${a.token}'}));
    expect(res.headers['content-type'], 'image/png');
    expect(await res.read().expand((x) => x).toList(), png);
    expect((await a.call('POST', '/v1/media', bytes: [1, 2], headers: {'content-type': 'text/html'})).$1, 415);
    expect((await Client(h).call('GET', '/v1/media/$id')).$1, 401);
    final small = PrismSocialServer(storage, config: const ServerConfig(maxMediaBytes: 4)).handler;
    expect((await Client(small, a.token).call('POST', '/v1/media', bytes: png, headers: {'content-type': 'image/png'})).$1, 413);
  });

  test('invite code, registration rate limit and write rate limit', () async {
    final invite = PrismSocialServer(MemoryStorage(), config: const ServerConfig(registrationCode: 'letmein')).handler;
    expect((await Client(invite).call('POST', '/v1/auth/register')).$1, 403);
    expect((await Client(invite).call('POST', '/v1/auth/register', headers: {'x-registration-code': 'letmein'})).$1, 201);

    final limited = PrismSocialServer(MemoryStorage(), config: const ServerConfig(registrationsPerHour: 2, writesPerMinute: 3)).handler;
    final c = await Client.register(limited);
    await Client.register(limited);
    expect((await Client(limited).call('POST', '/v1/auth/register')).$1, 429);
    final p = await c.rpc('createProfile', {'username': 'aurora', 'systemName': 'Aurora'}) as String;
    await c.rpc('touch', {'profileId': p});
    await c.rpc('touch', {'profileId': p});
    expect((await c.call('POST', '/v1/rpc/touch', body: {'profileId': p})).$1, 429);
  });

  test('bad requests are rejected cleanly', () async {
    final a = await Client.register(h);
    expect((await a.call('POST', '/v1/rpc/nope', body: {})).$1, 404);
    expect((await a.call('POST', '/v1/rpc/sendRequest', body: {'to': 'x'})).$1, 400);
    expect((await a.call('POST', '/v1/rpc/touch', bytes: utf8.encode('{not json'))).$1, 400);
    expect((await a.call('POST', '/v1/rpc/touch', body: {'profileId': 'missing'})).$1, 404);
  });

  test('deleting an account removes its systems and content', () async {
    final alice = await Client.register(h);
    final bob = await Client.register(h);
    final a = await alice.rpc('createProfile', {'username': 'aurora', 'systemName': 'Aurora'}) as String;
    await bob.rpc('createProfile', {'username': 'birch', 'systemName': 'Birch'});
    await alice.rpc('createPost', {'actor': {'p': a}, 'type': 'text', 'body': 'bye', 'audience': 'everyone'});
    expect((await alice.call('DELETE', '/v1/account')).$1, 200);
    expect((await alice.call('GET', '/v1/sync')).$1, 401);
    final bobView = await bob.sync();
    expect(bobView.any((r) => r['id'] == a || r['kind'] == 'soc.post'), isFalse);
  });
}
