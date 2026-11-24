import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'accounts.dart';
import 'server.dart' show hashToken;
import 'storage.dart';

/// Account limits.
class AccountConfig {
  const AccountConfig({this.maxBackupBytes = 60 * 1024 * 1024, this.backupsKept = 10, this.loginAttemptsPer15Min = 10, this.signupsPerHour = 10});
  final int maxBackupBytes;
  final int backupsKept;
  final int loginAttemptsPer15Min;
  final int signupsPerHour;
}

class _Window {
  _Window(this.limit, this.window);
  final int limit;
  final Duration window;
  final _hits = <String, List<DateTime>>{};
  bool allow(String key) {
    final now = DateTime.now();
    final list = _hits.putIfAbsent(key, () => [])..removeWhere((t) => now.difference(t) > window);
    if (list.length >= limit) return false;
    list.add(now);
    if (_hits.length > 50000) _hits.removeWhere((_, v) => v.isEmpty || now.difference(v.last) > window);
    return true;
  }
}

class AccountRoutes {
  AccountRoutes(this.storage, {this.config = const AccountConfig(), required this.clientIp, required this.json, required this.error, required this.body})
    : _logins = _Window(config.loginAttemptsPer15Min, const Duration(minutes: 15)),
      _signups = _Window(config.signupsPerHour, const Duration(hours: 1));

  final ServerStorage storage;
  final AccountConfig config;
  final String Function(Request) clientIp;
  final Response Function(Object? body, {int status}) json;
  final Response Function(int status, String code, [String? message]) error;
  final Future<Map<String, Object?>> Function(Request req) body;
  final _Window _logins;
  final _Window _signups;

  AccountStore get _db => storage.users;

  void mount(Router r) {
    r
      ..post('/v1/accounts/signup', _signup)
      ..post('/v1/accounts/login', _login)
      ..post('/v1/accounts/logout', _logout)
      ..get('/v1/accounts/me', _me)
      ..post('/v1/accounts/email', _setEmail)
      ..post('/v1/accounts/secret', _changeSecret)
      ..delete('/v1/accounts/sessions/<id>', _revokeSession)
      ..post('/v1/accounts/totp/setup', _totpSetup)
      ..post('/v1/accounts/totp/enable', _totpEnable)
      ..post('/v1/accounts/totp/disable', _totpDisable)
      ..post('/v1/accounts/delete', _deleteUser)
      ..get('/v1/backups', _listBackups)
      ..post('/v1/backups', _uploadBackup)
      ..get('/v1/backups/<id>', _getBackup)
      ..delete('/v1/backups/<id>', _deleteBackup);
  }

  // ── helpers

  Future<(UserRow, SessionRow)?> _auth(Request req) async {
    final h = req.headers['authorization'] ?? '';
    if (!h.startsWith('Bearer ')) return null;
    final token = h.substring(7).trim();
    if (token.length < 32) return null;
    final s = await _db.sessionByTokenHash(hashToken(token));
    if (s == null) return null;
    final u = await _db.userById(s.userId);
    if (u == null) return null;
    final now = DateTime.now();
    if (now.difference(s.lastSeen).inMinutes >= 10) await _db.touchSession(s.id, now);
    return (u, s);
  }

  String _str(Map<String, Object?> b, String k, {int max = 200}) {
    final v = '${b[k] ?? ''}'.trim();
    return v.length > max ? v.substring(0, max) : v;
  }

  /// The app sends a 64-hex-character secret derived from the password.
  bool _validSecret(String s) => RegExp(r'^[0-9a-f]{64}$').hasMatch(s);

  Future<Response> _issue(UserRow u, Map<String, Object?> b, {int status = 200}) async {
    final token = newId(32);
    final now = DateTime.now();
    final s = SessionRow(id: newSessionId(), tokenHash: hashToken(token), userId: u.id, device: _str(b, 'device', max: 80).ifEmpty('Device'), platform: _str(b, 'platform', max: 20).ifEmpty('unknown'), createdAt: now, lastSeen: now);
    await _db.insertSession(s);
    return json({'token': token, 'session': s.id, 'user': u.toPublic(), 'wrappedKey': u.wrappedKey}, status: status);
  }

  // ── accounts

  Future<Response> _signup(Request req) async {
    if (!_signups.allow('s:${clientIp(req)}')) return error(429, 'rate_limited');
    final b = await body(req);
    final username = _str(b, 'username', max: 32);
    final email = _str(b, 'email', max: 200);
    final secret = _str(b, 'secret', max: 64);
    final wrapped = _str(b, 'wrappedKey', max: 4096);
    if (!usernamePattern.hasMatch(username)) return error(400, 'invalid_username', 'Use 3–32 letters, numbers, dots, dashes or underscores.');
    if (email.isNotEmpty && !emailPattern.hasMatch(email)) return error(400, 'invalid_email');
    if (!_validSecret(secret)) return error(400, 'invalid_secret');
    if (await _db.userByName(username.toLowerCase()) != null) return error(409, 'username_taken');
    if (email.isNotEmpty && await _db.userByEmail(email.toLowerCase()) != null) return error(409, 'email_taken');
    final salt = newId(16);
    final u = UserRow(id: newId(), username: username, email: email.isEmpty ? null : email, secretHash: hashSecret(secret, salt), salt: salt, wrappedKey: wrapped.isEmpty ? null : wrapped, createdAt: DateTime.now());
    await _db.insertUser(u);
    return _issue(u, b, status: 201);
  }

  Future<Response> _login(Request req) async {
    final b = await body(req);
    final login = _str(b, 'login').toLowerCase();
    final secret = _str(b, 'secret', max: 64);
    if (!_logins.allow('l:${clientIp(req)}') || !_logins.allow('u:$login')) return error(429, 'rate_limited', 'Too many attempts. Try again in 15 minutes.');
    final u = login.contains('@') ? await _db.userByEmail(login) : await _db.userByName(login);
    // Same answer for unknown user and wrong password.
    if (u == null || !_validSecret(secret) || !safeEquals(hashSecret(secret, u.salt), u.secretHash)) return error(401, 'wrong_login', 'Username or password is incorrect.');
    if (u.totpSecret != null) {
      final code = _str(b, 'code', max: 10);
      if (code.isEmpty) return error(401, 'code_required', 'Enter the 6-digit code from your authenticator app.');
      if (!totpValid(u.totpSecret!, code, DateTime.now())) return error(401, 'wrong_code', 'That code didn\'t work.');
    }
    return _issue(u, b);
  }

  Future<Response> _logout(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    await _db.deleteSession(a.$2.id);
    return json({'ok': true});
  }

  Future<Response> _me(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final sessions = await _db.sessionsOf(a.$1.id);
    return json({'user': a.$1.toPublic(), 'wrappedKey': a.$1.wrappedKey, 'sessions': [for (final s in sessions) s.toPublic(current: s.id == a.$2.id)]});
  }

  Future<Response> _setEmail(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final email = _str(await body(req), 'email');
    if (email.isNotEmpty && !emailPattern.hasMatch(email)) return error(400, 'invalid_email');
    if (email.isNotEmpty) {
      final other = await _db.userByEmail(email.toLowerCase());
      if (other != null && other.id != a.$1.id) return error(409, 'email_taken');
    }
    a.$1.email = email.isEmpty ? null : email;
    await _db.updateUser(a.$1);
    return json({'user': a.$1.toPublic()});
  }

  /// Password change: the app sends the old and new derived secrets and the
  /// backup key re-wrapped with the new password. Signs out other devices.
  Future<Response> _changeSecret(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final b = await body(req);
    final current = _str(b, 'current', max: 64), next = _str(b, 'secret', max: 64);
    if (!safeEquals(hashSecret(current, a.$1.salt), a.$1.secretHash)) return error(401, 'wrong_login', 'Current password is incorrect.');
    if (!_validSecret(next)) return error(400, 'invalid_secret');
    a.$1
      ..salt = newId(16)
      ..secretHash = ''
      ..wrappedKey = _str(b, 'wrappedKey', max: 4096).ifEmpty(a.$1.wrappedKey ?? '');
    a.$1.secretHash = hashSecret(next, a.$1.salt);
    if (a.$1.wrappedKey == '') a.$1.wrappedKey = null;
    await _db.updateUser(a.$1);
    await _db.deleteSessionsOf(a.$1.id, except: a.$2.id);
    return json({'ok': true});
  }

  Future<Response> _revokeSession(Request req, String id) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final mine = await _db.sessionsOf(a.$1.id);
    if (!mine.any((s) => s.id == id)) return error(404, 'not_found');
    await _db.deleteSession(id);
    return json({'ok': true});
  }

  Future<Response> _totpSetup(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final secret = base32Encode(List<int>.generate(20, (i) => int.parse(newId(1), radix: 16)));
    a.$1.totpPending = secret;
    await _db.updateUser(a.$1);
    final label = Uri.encodeComponent('Prism:${a.$1.username}');
    return json({'secret': secret, 'uri': 'otpauth://totp/$label?secret=$secret&issuer=Prism&digits=6&period=30'});
  }

  Future<Response> _totpEnable(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final code = _str(await body(req), 'code', max: 10);
    final pending = a.$1.totpPending;
    if (pending == null) return error(400, 'no_setup');
    if (!totpValid(pending, code, DateTime.now())) return error(401, 'wrong_code', 'That code didn\'t work. Check the time on your phone and try again.');
    a.$1
      ..totpSecret = pending
      ..totpPending = null;
    await _db.updateUser(a.$1);
    return json({'user': a.$1.toPublic()});
  }

  Future<Response> _totpDisable(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final b = await body(req);
    if (!safeEquals(hashSecret(_str(b, 'secret', max: 64), a.$1.salt), a.$1.secretHash)) return error(401, 'wrong_login', 'Password is incorrect.');
    a.$1
      ..totpSecret = null
      ..totpPending = null;
    await _db.updateUser(a.$1);
    return json({'user': a.$1.toPublic()});
  }

  Future<Response> _deleteUser(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    if (!safeEquals(hashSecret(_str(await body(req), 'secret', max: 64), a.$1.salt), a.$1.secretHash)) return error(401, 'wrong_login', 'Password is incorrect.');
    await _db.deleteUser(a.$1.id);
    return json({'deleted': true});
  }

  // ── backups

  Future<Response> _listBackups(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    return json({'backups': [for (final m in await _db.backupsOf(a.$1.id)) m.toJson()]});
  }

  Future<Response> _uploadBackup(Request req) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final builder = BytesBuilder(copy: false);
    await for (final chunk in req.read()) {
      builder.add(chunk);
      if (builder.length > config.maxBackupBytes) return error(413, 'too_large');
    }
    if (builder.isEmpty) return error(400, 'empty');
    final bytes = builder.takeBytes();
    // Only encrypted Prism exports are accepted.
    if (bytes.length < 6 || utf8.decode(bytes.sublist(0, 6), allowMalformed: true) != 'PRISM1') return error(400, 'not_encrypted');
    String header(String k, int max) {
      final v = Uri.decodeComponent(req.headers[k] ?? '').trim();
      return v.length > max ? v.substring(0, max) : v;
    }

    final meta = BackupMeta(id: newId(), userId: a.$1.id, label: header('x-backup-label', 80).ifEmpty('Backup'), device: header('x-backup-device', 80).ifEmpty(a.$2.device), size: bytes.length, createdAt: DateTime.now());
    await _db.insertBackup(meta, bytes);
    final all = await _db.backupsOf(a.$1.id);
    for (final old in all.skip(config.backupsKept)) {
      await _db.deleteBackup(a.$1.id, old.id);
    }
    return json({'backup': meta.toJson()}, status: 201);
  }

  Future<Response> _getBackup(Request req, String id) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    final blob = await _db.backupBlob(a.$1.id, id);
    if (blob == null) return error(404, 'not_found');
    return Response.ok(blob, headers: {'content-type': 'application/octet-stream', 'cache-control': 'no-store'});
  }

  Future<Response> _deleteBackup(Request req, String id) async {
    final a = await _auth(req);
    if (a == null) return error(401, 'unauthorized');
    await _db.deleteBackup(a.$1.id, id);
    return json({'ok': true});
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
