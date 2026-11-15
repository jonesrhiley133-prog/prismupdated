import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:prism_social_core/prism_social_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'rpc.dart';
import 'storage.dart';

const serverVersion = '0.1.0';

class ServerConfig {
  const ServerConfig({
    this.maxMediaBytes = 8 * 1024 * 1024,
    this.maxMediaPerAccount = 200 * 1024 * 1024,
    this.maxProfilesPerAccount = 10,
    this.writesPerMinute = 120,
    this.registrationsPerHour = 20,
    this.allowRegistration = true,
    this.registrationCode,
  });

  final int maxMediaBytes;
  final int maxMediaPerAccount;
  final int maxProfilesPerAccount;
  final int writesPerMinute;
  final int registrationsPerHour;
  final bool allowRegistration;

  /// When set, new accounts must send this invite code (keeps a private
  /// server private).
  final String? registrationCode;
}

String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

/// Fixed-window rate limiter.
class _Limiter {
  _Limiter(this.limit, this.window);
  final int limit;
  final Duration window;
  final _hits = <String, (DateTime, int)>{};
  bool allow(String key) {
    final now = DateTime.now();
    final h = _hits[key];
    if (h == null || now.difference(h.$1) > window) {
      _hits[key] = (now, 1);
      if (_hits.length > 50000) _hits.removeWhere((_, v) => now.difference(v.$1) > window);
      return true;
    }
    if (h.$2 >= limit) return false;
    _hits[key] = (h.$1, h.$2 + 1);
    return true;
  }
}

/// Runs writes one at a time so the rules' duplicate checks can't race.
class _Lock {
  Future<void> _last = Future.value();
  Future<T> run<T>(Future<T> Function() f) {
    final prev = _last;
    final done = Completer<void>();
    _last = done.future;
    return prev.then((_) => f()).whenComplete(done.complete);
  }
}

class PrismSocialServer {
  PrismSocialServer(this.storage, {this.config = const ServerConfig()}) : _writes = _Limiter(config.writesPerMinute, const Duration(minutes: 1)), _regs = _Limiter(config.registrationsPerHour, const Duration(hours: 1));

  final ServerStorage storage;
  final ServerConfig config;
  final _Limiter _writes;
  final _Limiter _regs;
  final _lock = _Lock();

  /// Bumped on every write; clients send it back so idle polls are cheap.
  int _version = DateTime.now().millisecondsSinceEpoch;

  static const _cors = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
    'access-control-allow-headers': 'authorization, content-type, if-none-match, x-registration-code',
    'access-control-max-age': '86400',
  };

  Response _json(Object? body, {int status = 200, Map<String, String> headers = const {}}) =>
      Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8', ...headers});

  Response _error(int status, String code, [String? message]) => _json({'error': {'code': code, 'message': ?message}}, status: status);

  static int statusFor(String code) => switch (code) {
    'not_found' => 404,
    'duplicate' || 'already_friends' || 'username_taken' => 409,
    'invalid' => 400,
    _ => 403,
  };

  String _clientIp(Request req) => (req.headers['x-forwarded-for'] ?? '').split(',').first.trim().isNotEmpty ? req.headers['x-forwarded-for']!.split(',').first.trim() : ((req.context['shelf.io.connection_info'] as dynamic)?.remoteAddress?.address as String? ?? 'unknown');

  Future<String?> _account(Request req) async {
    final h = req.headers['authorization'] ?? '';
    if (!h.startsWith('Bearer ')) return null;
    final token = h.substring(7).trim();
    if (token.length < 32) return null;
    return storage.accountForTokenHash(hashToken(token));
  }

  Future<Set<String>> _profilesOf(String account) async => {for (final p in await storage.social.all(SocKind.profile)) if (p.str('owner') == account) p.id};

  Handler get handler {
    final r = Router()
      ..get('/', (Request _) => _json({'name': 'Prism Social', 'version': serverVersion}))
      ..get('/healthz', (Request _) async => await storage.healthy() ? _json({'ok': true}) : _error(503, 'unhealthy'))
      ..get('/v1/info', (Request _) => _json({'name': 'Prism Social', 'version': serverVersion, 'maxMediaBytes': config.maxMediaBytes, 'registration': config.allowRegistration ? (config.registrationCode == null ? 'open' : 'invite') : 'closed'}))
      ..post('/v1/auth/register', _register)
      ..post('/v1/rpc/<method>', _rpc)
      ..get('/v1/sync', _sync)
      ..post('/v1/media', _uploadMedia)
      ..get('/v1/media/<id>', _getMedia)
      ..delete('/v1/account', _deleteAccount);
    return const Pipeline().addMiddleware(_corsAndErrors()).addHandler(r.call);
  }

  Middleware _corsAndErrors() => (inner) => (req) async {
    if (req.method == 'OPTIONS') return Response.ok('', headers: _cors);
    Response res;
    try {
      res = await inner(req);
    } on BadRequest catch (e) {
      res = _error(400, 'bad_request', e.message);
    } on FormatException catch (e) {
      res = _error(400, 'bad_request', e.message);
    } catch (e, st) {
      print('ERROR ${req.method} ${req.url}: $e\n$st');
      res = _error(500, 'server_error');
    }
    return res.change(headers: _cors);
  };

  Future<Response> _register(Request req) async {
    if (!config.allowRegistration) return _error(403, 'registration_closed');
    if (config.registrationCode != null && req.headers['x-registration-code'] != config.registrationCode) return _error(403, 'invite_required');
    if (!_regs.allow('reg:${_clientIp(req)}')) return _error(429, 'rate_limited');
    final account = newId();
    final token = newId(32);
    await storage.createAccount(account, hashToken(token));
    return _json({'account': account, 'token': token}, status: 201);
  }

  Future<Map<String, Object?>> _body(Request req, {int max = 256 * 1024}) async {
    final bytes = await req.read().fold<List<int>>([], (a, b) {
      a.addAll(b);
      if (a.length > max) throw const BadRequest('request too large');
      return a;
    });
    if (bytes.isEmpty) return const {};
    final v = jsonDecode(utf8.decode(bytes));
    if (v is! Map) throw const BadRequest('body must be a JSON object');
    return v.cast<String, Object?>();
  }

  Future<Response> _rpc(Request req, String method) async {
    final account = await _account(req);
    if (account == null) return _error(401, 'unauthorized');
    final handler = rpcMethods[method];
    if (handler == null) return _error(404, 'unknown_method');
    if (!_writes.allow('w:$account')) return _error(429, 'rate_limited');
    final args = await _body(req);
    if (method == 'createProfile' && (await _profilesOf(account)).length >= config.maxProfilesPerAccount) return _error(403, 'too_many_profiles');
    try {
      final result = await _lock.run(() => handler(SocialRules(storage.social, account: account), args));
      _version++;
      return _json({'result': result, 'version': _version});
    } on SocialDenied catch (e) {
      return _error(statusFor(e.code), e.code, e.detail);
    }
  }

  Future<Response> _sync(Request req) async {
    final account = await _account(req);
    if (account == null) return _error(401, 'unauthorized');
    final v = _version;
    // Nothing changed anywhere since the client's last snapshot.
    if (req.url.queryParameters['v'] == '$v') return Response(304);
    final mine = await _profilesOf(account);
    final body = jsonEncode({'version': v, 'profiles': mine.toList(), 'records': [for (final r in await visibleTo(storage.social, mine)) r.toJson()]});
    return Response.ok(body, headers: {'content-type': 'application/json; charset=utf-8'});
  }

  static const _imageTypes = {'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic'};

  Future<Response> _uploadMedia(Request req) async {
    final account = await _account(req);
    if (account == null) return _error(401, 'unauthorized');
    if (!_writes.allow('w:$account')) return _error(429, 'rate_limited');
    final mime = (req.headers['content-type'] ?? '').split(';').first.trim().toLowerCase();
    if (!_imageTypes.contains(mime)) return _error(415, 'unsupported_media_type');
    final builder = BytesBuilder(copy: false);
    await for (final chunk in req.read()) {
      builder.add(chunk);
      if (builder.length > config.maxMediaBytes) return _error(413, 'too_large');
    }
    if (builder.isEmpty) return _error(400, 'empty');
    if (await storage.mediaBytesFor(account) + builder.length > config.maxMediaPerAccount) return _error(413, 'quota_exceeded');
    final id = await storage.putMedia(account, mime, builder.takeBytes());
    return _json({'id': id}, status: 201);
  }

  Future<Response> _getMedia(Request req, String id) async {
    if (await _account(req) == null) return _error(401, 'unauthorized');
    final m = await storage.getMedia(id);
    if (m == null) return _error(404, 'not_found');
    return Response.ok(m.bytes, headers: {'content-type': m.mime, 'cache-control': 'private, max-age=31536000, immutable'});
  }

  /// Deletes the account, its systems and everything they authored.
  Future<Response> _deleteAccount(Request req) async {
    final account = await _account(req);
    if (account == null) return _error(401, 'unauthorized');
    await _lock.run(() async {
      final store = storage.social;
      final mine = await _profilesOf(account);
      bool involves(SocRecord r) {
        for (final k in const ['from', 'to', 'by', 'who', 'a', 'b', 'owner']) {
          if (mine.contains(r.str(k))) return true;
        }
        final actor = SocialActor.fromJson(r.fields['author'] ?? r.fields['actor']);
        return actor != null && mine.contains(actor.profileId);
      }

      for (final kind in SocKind.all) {
        for (final r in await store.all(kind)) {
          final drop = switch (kind) {
            SocKind.profile => mine.contains(r.id),
            SocKind.alter => mine.contains(r.parentId),
            SocKind.notif => mine.contains(r.parentId) || involves(r),
            SocKind.message => mine.contains(SocialActor.fromJson(r.fields['sender'])?.profileId),
            SocKind.conversation => false,
            _ => involves(r),
          };
          if (drop) await store.delete(r.id);
        }
      }
      await storage.deleteMediaOf(account);
      await storage.deleteAccount(account);
      _version++;
    });
    return _json({'deleted': true});
  }
}
