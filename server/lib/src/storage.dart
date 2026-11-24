import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:prism_social_core/prism_social_core.dart';

import 'accounts.dart';
import 'accounts_pg.dart';

/// Everything the server persists.
abstract class ServerStorage {
  SocialStore get social;
  AccountStore get users;
  Future<void> init();
  Future<void> close();
  Future<bool> healthy();

  Future<void> createAccount(String id, String tokenHash);
  Future<String?> accountForTokenHash(String tokenHash);
  Future<void> deleteAccount(String id);

  Future<String> putMedia(String account, String mime, Uint8List bytes);
  Future<({String mime, Uint8List bytes})?> getMedia(String id);
  Future<int> mediaBytesFor(String account);
  Future<void> deleteMediaOf(String account);
}

final _rand = Random.secure();
String newId([int bytes = 16]) => List.generate(bytes, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// In-memory storage for tests and local experiments (data is lost on exit).
class MemoryStorage implements ServerStorage {
  @override
  final MemorySocialStore social = MemorySocialStore();
  @override
  final MemoryAccountStore users = MemoryAccountStore();
  final accounts = <String, String>{}; // tokenHash -> account
  final media = <String, ({String account, String mime, Uint8List bytes})>{};

  @override
  Future<void> init() async {}
  @override
  Future<void> close() async {}
  @override
  Future<bool> healthy() async => true;
  @override
  Future<void> createAccount(String id, String tokenHash) async => accounts[tokenHash] = id;
  @override
  Future<String?> accountForTokenHash(String tokenHash) async => accounts[tokenHash];
  @override
  Future<void> deleteAccount(String id) async => accounts.removeWhere((_, v) => v == id);
  @override
  Future<String> putMedia(String account, String mime, Uint8List bytes) async {
    final id = newId();
    media[id] = (account: account, mime: mime, bytes: bytes);
    return id;
  }

  @override
  Future<({String mime, Uint8List bytes})?> getMedia(String id) async {
    final m = media[id];
    return m == null ? null : (mime: m.mime, bytes: m.bytes);
  }

  @override
  Future<int> mediaBytesFor(String account) async => media.values.where((m) => m.account == account).fold<int>(0, (a, m) => a + m.bytes.length);
  @override
  Future<void> deleteMediaOf(String account) async => media.removeWhere((_, m) => m.account == account);
}

/// Adds `sslmode` when the URL has none: Railway's private network
/// (`*.railway.internal`) and localhost don't use TLS; anything else does.
String normalizeDatabaseUrl(String url, {String? sslMode}) {
  final uri = Uri.parse(url);
  if (uri.queryParameters.containsKey('sslmode')) return url;
  final host = uri.host;
  final mode = sslMode ?? ((host.endsWith('.railway.internal') || host == 'localhost' || host == '127.0.0.1') ? 'disable' : 'require');
  return uri.replace(queryParameters: {...uri.queryParameters, 'sslmode': mode}).toString();
}

/// Postgres storage (Railway's Postgres plugin provides `DATABASE_URL`).
class PostgresStorage implements ServerStorage {
  PostgresStorage(String url, {String? sslMode}) : _pool = Pool.withUrl(normalizeDatabaseUrl(url, sslMode: sslMode));
  final Pool<void> _pool;
  late final PgSocialStore _social = PgSocialStore(_pool);
  @override
  late final PgAccountStore users = PgAccountStore(_pool);
  @override
  SocialStore get social => _social;

  @override
  Future<void> init() async {
    await _pool.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        token_hash TEXT NOT NULL UNIQUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )''');
    await _pool.execute('''
      CREATE TABLE IF NOT EXISTS records (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        parent_id TEXT,
        title TEXT NOT NULL DEFAULT '',
        body TEXT,
        member_id TEXT,
        occurred_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL,
        modified_at TIMESTAMPTZ NOT NULL,
        fields JSONB NOT NULL DEFAULT '{}'::jsonb
      )''');
    await _pool.execute('CREATE INDEX IF NOT EXISTS records_kind ON records (kind)');
    await _pool.execute('''
      CREATE TABLE IF NOT EXISTS media (
        id TEXT PRIMARY KEY,
        account TEXT NOT NULL,
        mime TEXT NOT NULL,
        bytes BYTEA NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )''');
    await _pool.execute('CREATE INDEX IF NOT EXISTS media_account ON media (account)');
    await users.init();
  }

  @override
  Future<void> close() => _pool.close();

  /// Empties every table (tests only).
  Future<void> resetForTests() => _pool.execute('TRUNCATE accounts, records, media, users, user_sessions, backups');

  @override
  Future<bool> healthy() async {
    try {
      await _pool.execute('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> createAccount(String id, String tokenHash) async {
    await _pool.execute(Sql.named('INSERT INTO accounts (id, token_hash) VALUES (@id, @h)'), parameters: {'id': id, 'h': tokenHash});
  }

  @override
  Future<String?> accountForTokenHash(String tokenHash) async {
    final r = await _pool.execute(Sql.named('SELECT id FROM accounts WHERE token_hash = @h'), parameters: {'h': tokenHash});
    return r.isEmpty ? null : r.first[0]! as String;
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _pool.execute(Sql.named('DELETE FROM accounts WHERE id = @id'), parameters: {'id': id});
  }

  @override
  Future<String> putMedia(String account, String mime, Uint8List bytes) async {
    final id = newId();
    await _pool.execute(Sql.named('INSERT INTO media (id, account, mime, bytes) VALUES (@id, @a, @m, @b)'), parameters: {'id': id, 'a': account, 'm': mime, 'b': TypedValue(Type.byteArray, bytes)});
    return id;
  }

  @override
  Future<({String mime, Uint8List bytes})?> getMedia(String id) async {
    final r = await _pool.execute(Sql.named('SELECT mime, bytes FROM media WHERE id = @id'), parameters: {'id': id});
    if (r.isEmpty) return null;
    final b = r.first[1];
    return (mime: r.first[0]! as String, bytes: b is Uint8List ? b : Uint8List.fromList((b! as List).cast<int>()));
  }

  @override
  Future<int> mediaBytesFor(String account) async {
    final r = await _pool.execute(Sql.named('SELECT COALESCE(SUM(octet_length(bytes)), 0) FROM media WHERE account = @a'), parameters: {'a': account});
    return (r.first[0]! as num).toInt();
  }

  @override
  Future<void> deleteMediaOf(String account) async {
    await _pool.execute(Sql.named('DELETE FROM media WHERE account = @a'), parameters: {'a': account});
  }
}

class PgSocialStore implements SocialStore {
  PgSocialStore(this._db);
  final Session _db;

  static SocRecord _row(ResultRow r) {
    final f = r[9];
    return SocRecord(
      id: r[0]! as String,
      kind: r[1]! as String,
      parentId: r[2] as String?,
      title: (r[3] as String?) ?? '',
      body: r[4] as String?,
      memberId: r[5] as String?,
      occurredAt: (r[6] as DateTime?)?.toLocal(),
      createdAt: (r[7]! as DateTime).toLocal(),
      modifiedAt: (r[8]! as DateTime).toLocal(),
      fields: f is Map ? f.cast<String, Object?>() : (f is String ? (jsonDecode(f) as Map).cast<String, Object?>() : const {}),
    );
  }

  @override
  Future<List<SocRecord>> all(String kind) async {
    final r = await _db.execute(Sql.named('SELECT id, kind, parent_id, title, body, member_id, occurred_at, created_at, modified_at, fields FROM records WHERE kind = @k'), parameters: {'k': kind});
    return [for (final row in r) _row(row)];
  }

  Map<String, Object?> _params(SocRecord r) => {
    'id': r.id,
    'kind': r.kind,
    'parent': r.parentId,
    'title': r.title,
    'body': r.body,
    'member': r.memberId,
    'occurred': TypedValue(Type.timestampTz, r.occurredAt?.toUtc()),
    'created': TypedValue(Type.timestampTz, r.createdAt.toUtc()),
    'modified': TypedValue(Type.timestampTz, r.modifiedAt.toUtc()),
    'fields': TypedValue(Type.jsonb, r.fields),
  };

  @override
  Future<SocRecord> create({required String kind, String title = '', String? body, String? parentId, String? memberId, Map<String, Object?> fields = const {}, DateTime? occurredAt}) async {
    final now = DateTime.now();
    final r = SocRecord(id: newId(), kind: kind, title: title, body: body, parentId: parentId, memberId: memberId, occurredAt: occurredAt, createdAt: now, modifiedAt: now).withFields(fields);
    await _db.execute(
      Sql.named('INSERT INTO records (id, kind, parent_id, title, body, member_id, occurred_at, created_at, modified_at, fields) VALUES (@id, @kind, @parent, @title, @body, @member, @occurred, @created, @modified, @fields)'),
      parameters: _params(r),
    );
    return r;
  }

  @override
  Future<void> save(SocRecord record) async {
    final r = record.copyWith(modifiedAt: DateTime.now());
    await _db.execute(
      Sql.named('UPDATE records SET parent_id = @parent, title = @title, body = @body, member_id = @member, occurred_at = @occurred, modified_at = @modified, fields = @fields WHERE id = @id'),
      parameters: {..._params(r)}..remove('kind')..remove('created'),
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.execute(Sql.named('DELETE FROM records WHERE id = @id'), parameters: {'id': id});
  }
}
