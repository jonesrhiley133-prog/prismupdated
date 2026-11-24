import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'storage.dart';

/// Optional accounts: username (+ optional email) and password, device
/// sessions, two-step codes (TOTP) and end-to-end encrypted backups.
///
/// Zero-knowledge: the app never sends the password. It sends a secret
/// derived from it (scrypt, salted with the username), which is hashed again
/// here. Backups and the wrapped backup key are encrypted on the device; the
/// server stores bytes it can't read.

class UserRow {
  UserRow({required this.id, required this.username, this.email, required this.secretHash, required this.salt, this.totpSecret, this.totpPending, this.wrappedKey, required this.createdAt});
  final String id;
  final String username;
  String? email;
  String secretHash;
  String salt;
  String? totpSecret;
  String? totpPending;
  String? wrappedKey;
  final DateTime createdAt;

  Map<String, Object?> toPublic() => {'id': id, 'username': username, 'email': email, 'twoStep': totpSecret != null, 'createdAt': createdAt.toUtc().toIso8601String()};
}

class SessionRow {
  SessionRow({required this.id, required this.tokenHash, required this.userId, required this.device, required this.platform, required this.createdAt, required this.lastSeen});
  final String id;
  final String tokenHash;
  final String userId;
  final String device;
  final String platform;
  final DateTime createdAt;
  DateTime lastSeen;

  Map<String, Object?> toPublic({bool current = false}) => {'id': id, 'device': device, 'platform': platform, 'createdAt': createdAt.toUtc().toIso8601String(), 'lastSeen': lastSeen.toUtc().toIso8601String(), 'current': current};
}

class BackupMeta {
  BackupMeta({required this.id, required this.userId, required this.label, required this.device, required this.size, required this.createdAt});
  final String id;
  final String userId;
  final String label;
  final String device;
  final int size;
  final DateTime createdAt;
  Map<String, Object?> toJson() => {'id': id, 'label': label, 'device': device, 'size': size, 'createdAt': createdAt.toUtc().toIso8601String()};
}

/// Account persistence (memory for tests, Postgres in production).
abstract class AccountStore {
  Future<void> init();
  Future<UserRow?> userByName(String usernameLower);
  Future<UserRow?> userByEmail(String emailLower);
  Future<UserRow?> userById(String id);
  Future<void> insertUser(UserRow u);
  Future<void> updateUser(UserRow u);
  Future<void> deleteUser(String id);

  Future<void> insertSession(SessionRow s);
  Future<SessionRow?> sessionByTokenHash(String hash);
  Future<List<SessionRow>> sessionsOf(String userId);
  Future<void> touchSession(String id, DateTime at);
  Future<void> deleteSession(String id);
  Future<void> deleteSessionsOf(String userId, {String? except});

  Future<void> insertBackup(BackupMeta m, Uint8List blob);
  Future<List<BackupMeta>> backupsOf(String userId);
  Future<Uint8List?> backupBlob(String userId, String id);
  Future<void> deleteBackup(String userId, String id);
}

class MemoryAccountStore implements AccountStore {
  final users = <String, UserRow>{};
  final sessions = <String, SessionRow>{};
  final backups = <String, (BackupMeta, Uint8List)>{};

  @override
  Future<void> init() async {}
  @override
  Future<UserRow?> userByName(String u) async => users.values.where((x) => x.username.toLowerCase() == u).firstOrNull;
  @override
  Future<UserRow?> userByEmail(String e) async => users.values.where((x) => x.email?.toLowerCase() == e).firstOrNull;
  @override
  Future<UserRow?> userById(String id) async => users[id];
  @override
  Future<void> insertUser(UserRow u) async => users[u.id] = u;
  @override
  Future<void> updateUser(UserRow u) async => users[u.id] = u;
  @override
  Future<void> deleteUser(String id) async {
    users.remove(id);
    sessions.removeWhere((_, s) => s.userId == id);
    backups.removeWhere((_, b) => b.$1.userId == id);
  }

  @override
  Future<void> insertSession(SessionRow s) async => sessions[s.id] = s;
  @override
  Future<SessionRow?> sessionByTokenHash(String h) async => sessions.values.where((s) => s.tokenHash == h).firstOrNull;
  @override
  Future<List<SessionRow>> sessionsOf(String userId) async => sessions.values.where((s) => s.userId == userId).toList();
  @override
  Future<void> touchSession(String id, DateTime at) async => sessions[id]?.lastSeen = at;
  @override
  Future<void> deleteSession(String id) async => sessions.remove(id);
  @override
  Future<void> deleteSessionsOf(String userId, {String? except}) async => sessions.removeWhere((k, s) => s.userId == userId && k != except);

  @override
  Future<void> insertBackup(BackupMeta m, Uint8List blob) async => backups[m.id] = (m, blob);
  @override
  Future<List<BackupMeta>> backupsOf(String userId) async => [for (final b in backups.values) if (b.$1.userId == userId) b.$1]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<Uint8List?> backupBlob(String userId, String id) async {
    final b = backups[id];
    return b == null || b.$1.userId != userId ? null : b.$2;
  }

  @override
  Future<void> deleteBackup(String userId, String id) async {
    if (backups[id]?.$1.userId == userId) backups.remove(id);
  }
}

// ── Crypto helpers ──────────────────────────────────────────────────────

/// PBKDF2-HMAC-SHA256.
Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
  final hmac = Hmac(sha256, password);
  final out = BytesBuilder();
  var block = 1;
  while (out.length < length) {
    final u0 = hmac.convert([...salt, (block >> 24) & 0xff, (block >> 16) & 0xff, (block >> 8) & 0xff, block & 0xff]).bytes;
    var u = u0;
    final t = List<int>.from(u0);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
    block++;
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}

const pbkdf2Iterations = 60000;

String hashSecret(String secret, String salt) => base64.encode(pbkdf2(utf8.encode(secret), utf8.encode(salt), pbkdf2Iterations, 32));

/// Constant-time string comparison.
bool safeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var r = 0;
  for (var i = 0; i < a.length; i++) {
    r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return r == 0;
}

const _b32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String base32Encode(List<int> bytes) {
  final sb = StringBuffer();
  var buffer = 0, bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      sb.write(_b32[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) sb.write(_b32[(buffer << (5 - bits)) & 31]);
  return sb.toString();
}

Uint8List base32Decode(String s) {
  final out = <int>[];
  var buffer = 0, bits = 0;
  for (final ch in s.toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '').split('')) {
    buffer = (buffer << 5) | _b32.indexOf(ch);
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}

/// RFC 6238 time-based code (SHA-1, 30 s, 6 digits).
String totpCode(String secretB32, DateTime at) {
  final counter = at.millisecondsSinceEpoch ~/ 1000 ~/ 30;
  final msg = Uint8List(8);
  var c = counter;
  for (var i = 7; i >= 0; i--) {
    msg[i] = c & 0xff;
    c >>= 8;
  }
  final h = Hmac(sha1, base32Decode(secretB32)).convert(msg).bytes;
  final o = h.last & 0x0f;
  final bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  return (bin % 1000000).toString().padLeft(6, '0');
}

/// Accepts the current code and one step either side (clock drift).
bool totpValid(String secretB32, String code, DateTime now) {
  final c = code.replaceAll(RegExp(r'\s'), '');
  if (c.length != 6) return false;
  for (final d in const [-30, 0, 30]) {
    if (safeEquals(totpCode(secretB32, now.add(Duration(seconds: d))), c)) return true;
  }
  return false;
}

final usernamePattern = RegExp(r'^[a-zA-Z0-9_.-]{3,32}$');
final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String newSessionId() => newId(8);
