import 'dart:typed_data';

import 'package:postgres/postgres.dart';

import 'accounts.dart';

class PgAccountStore implements AccountStore {
  PgAccountStore(this._db);
  final Pool<void> _db;

  @override
  Future<void> init() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        username_lower TEXT NOT NULL UNIQUE,
        email TEXT,
        email_lower TEXT UNIQUE,
        secret_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        totp_secret TEXT,
        totp_pending TEXT,
        wrapped_key TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )''');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS user_sessions (
        id TEXT PRIMARY KEY,
        token_hash TEXT NOT NULL UNIQUE,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        device TEXT NOT NULL,
        platform TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL,
        last_seen TIMESTAMPTZ NOT NULL
      )''');
    await _db.execute('CREATE INDEX IF NOT EXISTS user_sessions_user ON user_sessions (user_id)');
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS backups (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        device TEXT NOT NULL,
        size INTEGER NOT NULL,
        blob BYTEA NOT NULL,
        created_at TIMESTAMPTZ NOT NULL
      )''');
    await _db.execute('CREATE INDEX IF NOT EXISTS backups_user ON backups (user_id, created_at)');
  }

  static const _userCols = 'id, username, email, secret_hash, salt, totp_secret, totp_pending, wrapped_key, created_at';

  UserRow _user(ResultRow r) => UserRow(
    id: r[0]! as String,
    username: r[1]! as String,
    email: r[2] as String?,
    secretHash: r[3]! as String,
    salt: r[4]! as String,
    totpSecret: r[5] as String?,
    totpPending: r[6] as String?,
    wrappedKey: r[7] as String?,
    createdAt: (r[8]! as DateTime).toLocal(),
  );

  Future<UserRow?> _one(String where, Map<String, Object?> p) async {
    final r = await _db.execute(Sql.named('SELECT $_userCols FROM users WHERE $where'), parameters: p);
    return r.isEmpty ? null : _user(r.first);
  }

  @override
  Future<UserRow?> userByName(String u) => _one('username_lower = @v', {'v': u});
  @override
  Future<UserRow?> userByEmail(String e) => _one('email_lower = @v', {'v': e});
  @override
  Future<UserRow?> userById(String id) => _one('id = @v', {'v': id});

  Map<String, Object?> _userParams(UserRow u) => {
    'id': u.id,
    'username': u.username,
    'ul': u.username.toLowerCase(),
    'email': u.email,
    'el': u.email?.toLowerCase(),
    'sh': u.secretHash,
    'salt': u.salt,
    'ts': u.totpSecret,
    'tp': u.totpPending,
    'wk': u.wrappedKey,
  };

  @override
  Future<void> insertUser(UserRow u) async {
    await _db.execute(
      Sql.named('INSERT INTO users (id, username, username_lower, email, email_lower, secret_hash, salt, totp_secret, totp_pending, wrapped_key) VALUES (@id, @username, @ul, @email, @el, @sh, @salt, @ts, @tp, @wk)'),
      parameters: _userParams(u),
    );
  }

  @override
  Future<void> updateUser(UserRow u) async {
    await _db.execute(
      Sql.named('UPDATE users SET email = @email, email_lower = @el, secret_hash = @sh, salt = @salt, totp_secret = @ts, totp_pending = @tp, wrapped_key = @wk WHERE id = @id'),
      parameters: _userParams(u)..remove('username')..remove('ul'),
    );
  }

  @override
  Future<void> deleteUser(String id) async {
    await _db.execute(Sql.named('DELETE FROM users WHERE id = @id'), parameters: {'id': id});
  }

  SessionRow _session(ResultRow r) => SessionRow(
    id: r[0]! as String,
    tokenHash: r[1]! as String,
    userId: r[2]! as String,
    device: r[3]! as String,
    platform: r[4]! as String,
    createdAt: (r[5]! as DateTime).toLocal(),
    lastSeen: (r[6]! as DateTime).toLocal(),
  );

  static const _sessCols = 'id, token_hash, user_id, device, platform, created_at, last_seen';

  @override
  Future<void> insertSession(SessionRow s) async {
    await _db.execute(
      Sql.named('INSERT INTO user_sessions ($_sessCols) VALUES (@id, @th, @u, @d, @p, @c, @l)'),
      parameters: {'id': s.id, 'th': s.tokenHash, 'u': s.userId, 'd': s.device, 'p': s.platform, 'c': TypedValue(Type.timestampTz, s.createdAt.toUtc()), 'l': TypedValue(Type.timestampTz, s.lastSeen.toUtc())},
    );
  }

  @override
  Future<SessionRow?> sessionByTokenHash(String h) async {
    final r = await _db.execute(Sql.named('SELECT $_sessCols FROM user_sessions WHERE token_hash = @h'), parameters: {'h': h});
    return r.isEmpty ? null : _session(r.first);
  }

  @override
  Future<List<SessionRow>> sessionsOf(String userId) async {
    final r = await _db.execute(Sql.named('SELECT $_sessCols FROM user_sessions WHERE user_id = @u ORDER BY last_seen DESC'), parameters: {'u': userId});
    return [for (final row in r) _session(row)];
  }

  @override
  Future<void> touchSession(String id, DateTime at) async {
    await _db.execute(Sql.named('UPDATE user_sessions SET last_seen = @l WHERE id = @id'), parameters: {'id': id, 'l': TypedValue(Type.timestampTz, at.toUtc())});
  }

  @override
  Future<void> deleteSession(String id) async {
    await _db.execute(Sql.named('DELETE FROM user_sessions WHERE id = @id'), parameters: {'id': id});
  }

  @override
  Future<void> deleteSessionsOf(String userId, {String? except}) async {
    await _db.execute(Sql.named('DELETE FROM user_sessions WHERE user_id = @u AND id <> @e'), parameters: {'u': userId, 'e': except ?? ''});
  }

  @override
  Future<void> insertBackup(BackupMeta m, Uint8List blob) async {
    await _db.execute(
      Sql.named('INSERT INTO backups (id, user_id, label, device, size, blob, created_at) VALUES (@id, @u, @l, @d, @s, @b, @c)'),
      parameters: {'id': m.id, 'u': m.userId, 'l': m.label, 'd': m.device, 's': m.size, 'b': TypedValue(Type.byteArray, blob), 'c': TypedValue(Type.timestampTz, m.createdAt.toUtc())},
    );
  }

  @override
  Future<List<BackupMeta>> backupsOf(String userId) async {
    final r = await _db.execute(Sql.named('SELECT id, user_id, label, device, size, created_at FROM backups WHERE user_id = @u ORDER BY created_at DESC'), parameters: {'u': userId});
    return [
      for (final row in r) BackupMeta(id: row[0]! as String, userId: row[1]! as String, label: row[2]! as String, device: row[3]! as String, size: (row[4]! as num).toInt(), createdAt: (row[5]! as DateTime).toLocal()),
    ];
  }

  @override
  Future<Uint8List?> backupBlob(String userId, String id) async {
    final r = await _db.execute(Sql.named('SELECT blob FROM backups WHERE id = @id AND user_id = @u'), parameters: {'id': id, 'u': userId});
    if (r.isEmpty) return null;
    final b = r.first[0];
    return b is Uint8List ? b : Uint8List.fromList((b! as List).cast<int>());
  }

  @override
  Future<void> deleteBackup(String userId, String id) async {
    await _db.execute(Sql.named('DELETE FROM backups WHERE id = @id AND user_id = @u'), parameters: {'id': id, 'u': userId});
  }
}
