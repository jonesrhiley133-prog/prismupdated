import 'dart:convert';

import 'package:prism_social_server/prism_social_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

String secretOf(String s) => List.filled(64, s).join().substring(0, 64);

void main() {
  late Handler h;
  setUp(() => h = PrismSocialServer(MemoryStorage()).handler);

  Future<(int, Map<String, Object?>)> call(String method, String path, {Object? body, String? token, List<int>? bytes, Map<String, String> headers = const {}}) async {
    final res = await h(Request(method, Uri.parse('http://localhost$path'), body: bytes ?? (body == null ? null : jsonEncode(body)), headers: {if (token != null) 'authorization': 'Bearer $token', ...headers}));
    final text = await res.readAsString();
    if (!(res.headers['content-type'] ?? '').contains('json')) return (res.statusCode, {'raw': text});
    return (res.statusCode, (jsonDecode(text) as Map).cast<String, Object?>());
  }

  String err(Map<String, Object?> b) => (b['error'] as Map)['code'] as String;

  test('TOTP matches the RFC 6238 test vector', () {
    final secret = base32Encode(utf8.encode('12345678901234567890'));
    expect(totpCode(secret, DateTime.fromMillisecondsSinceEpoch(59 * 1000, isUtc: true)), '287082');
    expect(base32Decode(secret), utf8.encode('12345678901234567890'));
  });

  test('sign up, log in, wrong password, devices, log out', () async {
    var (code, b) = await call('POST', '/v1/accounts/signup', body: {'username': 'Moon_System', 'email': 'a@b.co', 'secret': secretOf('a'), 'wrappedKey': 'WRAPPED', 'device': 'Pixel'});
    expect(code, 201);
    final t1 = b['token'] as String;
    expect((b['user'] as Map)['username'], 'Moon_System');

    (code, b) = await call('POST', '/v1/accounts/signup', body: {'username': 'moon_system', 'secret': secretOf('b')});
    expect(err(b), 'username_taken');

    (code, b) = await call('POST', '/v1/accounts/login', body: {'login': 'MOON_SYSTEM', 'secret': secretOf('b')});
    expect(code, 401);
    expect(err(b), 'wrong_login');
    (code, b) = await call('POST', '/v1/accounts/login', body: {'login': 'a@b.co', 'secret': secretOf('a'), 'device': 'iPad'});
    expect(code, 200);
    expect(b['wrappedKey'], 'WRAPPED');
    final t2 = b['token'] as String;

    (code, b) = await call('GET', '/v1/accounts/me', token: t2);
    final sessions = b['sessions'] as List;
    expect(sessions.length, 2);
    final other = sessions.firstWhere((s) => (s as Map)['current'] == false) as Map;

    (code, b) = await call('DELETE', '/v1/accounts/sessions/${other['id']}', token: t2);
    expect(code, 200);
    (code, _) = await call('GET', '/v1/accounts/me', token: t1);
    expect(code, 401);

    (code, _) = await call('POST', '/v1/accounts/logout', token: t2);
    (code, _) = await call('GET', '/v1/accounts/me', token: t2);
    expect(code, 401);
  });

  test('two-step codes are required once enabled', () async {
    var (_, b) = await call('POST', '/v1/accounts/signup', body: {'username': 'sun', 'secret': secretOf('c')});
    final t = b['token'] as String;
    (_, b) = await call('POST', '/v1/accounts/totp/setup', token: t);
    final secret = b['secret'] as String;
    expect(b['uri'], startsWith('otpauth://totp/'));
    var (code, b2) = await call('POST', '/v1/accounts/totp/enable', token: t, body: {'code': '000000'});
    expect(code, 401);
    (code, b2) = await call('POST', '/v1/accounts/totp/enable', token: t, body: {'code': totpCode(secret, DateTime.now())});
    expect((b2['user'] as Map)['twoStep'], isTrue);

    (code, b2) = await call('POST', '/v1/accounts/login', body: {'login': 'sun', 'secret': secretOf('c')});
    expect(err(b2), 'code_required');
    (code, b2) = await call('POST', '/v1/accounts/login', body: {'login': 'sun', 'secret': secretOf('c'), 'code': totpCode(secret, DateTime.now())});
    expect(code, 200);
  });

  test('password change signs out other devices and re-wraps the key', () async {
    var (_, b) = await call('POST', '/v1/accounts/signup', body: {'username': 'star', 'secret': secretOf('d'), 'wrappedKey': 'OLD'});
    final t1 = b['token'] as String;
    (_, b) = await call('POST', '/v1/accounts/login', body: {'login': 'star', 'secret': secretOf('d')});
    final t2 = b['token'] as String;
    var (code, _) = await call('POST', '/v1/accounts/secret', token: t1, body: {'current': secretOf('d'), 'secret': secretOf('e'), 'wrappedKey': 'NEW'});
    expect(code, 200);
    (code, _) = await call('GET', '/v1/accounts/me', token: t2);
    expect(code, 401);
    (code, b) = await call('POST', '/v1/accounts/login', body: {'login': 'star', 'secret': secretOf('e')});
    expect(b['wrappedKey'], 'NEW');
  });

  test('backups: only encrypted, newest kept, private to the owner', () async {
    final h2 = PrismSocialServer(MemoryStorage(), accountConfig: const AccountConfig(backupsKept: 2)).handler;
    h = h2;
    var (_, b) = await call('POST', '/v1/accounts/signup', body: {'username': 'kite', 'secret': secretOf('f')});
    final t = b['token'] as String;
    (_, b) = await call('POST', '/v1/accounts/signup', body: {'username': 'other', 'secret': secretOf('f')});
    final other = b['token'] as String;

    var (code, b2) = await call('POST', '/v1/backups', token: t, bytes: utf8.encode('{"plain":true}'));
    expect(err(b2), 'not_encrypted');
    for (var i = 0; i < 3; i++) {
      (code, b2) = await call('POST', '/v1/backups', token: t, bytes: utf8.encode('PRISM1-blob-$i'), headers: {'x-backup-label': 'Auto%20$i'});
      expect(code, 201);
    }
    (code, b2) = await call('GET', '/v1/backups', token: t);
    final list = b2['backups'] as List;
    expect(list.length, 2);
    expect((list.first as Map)['label'], 'Auto 2');
    final id = (list.first as Map)['id'];
    final res = await h(Request('GET', Uri.parse('http://localhost/v1/backups/$id'), headers: {'authorization': 'Bearer $t'}));
    expect(await res.readAsString(), 'PRISM1-blob-2');
    (code, _) = await call('GET', '/v1/backups/$id', token: other);
    expect(code, 404);

    (code, _) = await call('POST', '/v1/accounts/delete', token: t, body: {'secret': secretOf('x')});
    expect(code, 401);
    (code, _) = await call('POST', '/v1/accounts/delete', token: t, body: {'secret': secretOf('f')});
    expect(code, 200);
    (code, _) = await call('GET', '/v1/backups', token: t);
    expect(code, 401);
  });
}
