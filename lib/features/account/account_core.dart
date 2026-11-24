import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as hp;

import 'package:prism_plurality/core/services/secure_storage.dart';
import 'package:prism_plurality/features/data_management/providers/data_management_providers.dart';
import 'package:prism_plurality/features/data_management/services/data_import_service.dart';
import 'package:prism_plurality/features/data_management/services/export_crypto.dart';
import 'package:prism_plurality/features/data_management/services/fast_scrypt.dart';
import 'package:prism_plurality/features/prism_social/social_remote.dart'
    show normalizeServerUrl;

// ── Keys ─────────────────────────────────────────────────────────────────
//
// Zero-knowledge design:
//  • login secret = scrypt(password, "prism-account-v1:" + username). The
//    password itself never leaves the device.
//  • backup key = random, shown once as a recovery key. Backups are Prism's
//    encrypted export format, locked with this key.
//  • the server keeps the backup key only wrapped (encrypted) with the
//    password, so signing in on a new device can unlock old backups.

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _deriveSync((String, String) a) => _hex(
  fastScrypt(
    Uint8List.fromList(utf8.encode(a.$2)),
    Uint8List.fromList(
      utf8.encode('prism-account-v1:${a.$1.trim().toLowerCase()}'),
    ),
    n: 16384,
    r: 8,
    p: 1,
    dkLen: 32,
  ),
);

/// The secret sent instead of the password.
Future<String> deriveLoginSecret(String username, String password) async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
  return kIsWeb
      ? _deriveSync((username, password))
      : compute(_deriveSync, (username, password));
}

const _b32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I, O, 0, 1

/// A new recovery key: 25 characters in groups of five.
String newRecoveryKey() {
  final r = Random.secure();
  final chars = List.generate(25, (_) => _b32[r.nextInt(_b32.length)]).join();
  return [for (var i = 0; i < 25; i += 5) chars.substring(i, i + 5)].join('-');
}

String normalizeRecoveryKey(String k) =>
    k.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

Uint8List _wrapSync((String, String) a) =>
    ExportCrypto.encrypt(a.$1, const [], a.$2);

Future<String> wrapKey(String recoveryKey, String password) async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
  final key = normalizeRecoveryKey(recoveryKey);
  return base64.encode(
    kIsWeb
        ? _wrapSync((key, password))
        : await compute(_wrapSync, (key, password)),
  );
}

Future<String?> unwrapKey(String wrapped, String password) async {
  try {
    final r = await ExportCrypto.decryptAsync(base64.decode(wrapped), password);
    return r.json;
  } catch (_) {
    return null;
  }
}

// ── Saved accounts ──────────────────────────────────────────────────────

@immutable
class SavedAccount {
  const SavedAccount({
    required this.server,
    required this.username,
    required this.userId,
    required this.token,
    this.backupKey,
    this.autoBackup = true,
    this.lastBackupAt,
    this.email,
    this.twoStep = false,
  });
  final String server;
  final String username;
  final String userId;
  final String token;

  /// The normalized recovery key (null if it couldn't be unlocked).
  final String? backupKey;
  final bool autoBackup;
  final DateTime? lastBackupAt;
  final String? email;
  final bool twoStep;

  String get key => '$server|$userId';

  SavedAccount copyWith({
    String? token,
    String? backupKey,
    bool? autoBackup,
    DateTime? lastBackupAt,
    String? email,
    bool clearEmail = false,
    bool? twoStep,
  }) => SavedAccount(
    server: server,
    username: username,
    userId: userId,
    token: token ?? this.token,
    backupKey: backupKey ?? this.backupKey,
    autoBackup: autoBackup ?? this.autoBackup,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    email: clearEmail ? null : (email ?? this.email),
    twoStep: twoStep ?? this.twoStep,
  );

  Map<String, Object?> toJson() => {
    'server': server,
    'username': username,
    'userId': userId,
    'token': token,
    'backupKey': backupKey,
    'autoBackup': autoBackup,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'email': email,
    'twoStep': twoStep,
  };

  static SavedAccount fromJson(Map<String, Object?> j) => SavedAccount(
    server: j['server']! as String,
    username: j['username']! as String,
    userId: j['userId']! as String,
    token: j['token']! as String,
    backupKey: j['backupKey'] as String?,
    autoBackup: j['autoBackup'] != false,
    lastBackupAt: DateTime.tryParse('${j['lastBackupAt'] ?? ''}'),
    email: j['email'] as String?,
    twoStep: j['twoStep'] == true,
  );
}

@immutable
class AccountsState {
  const AccountsState(this.accounts, this.activeKey);
  final List<SavedAccount> accounts;
  final String? activeKey;
  SavedAccount? get active =>
      accounts.where((a) => a.key == activeKey).firstOrNull ??
      accounts.firstOrNull;
}

const _storeKey = 'prism_accounts_v1';

class AccountsNotifier extends AsyncNotifier<AccountsState> {
  @override
  Future<AccountsState> build() async {
    final r = await safeSecureRead(_storeKey);
    final raw = r.ok ? r.value : null;
    if (raw == null) return const AccountsState([], null);
    try {
      final j = jsonDecode(raw) as Map;
      return AccountsState([
        for (final a in (j['accounts'] as List? ?? const []))
          SavedAccount.fromJson((a as Map).cast()),
      ], j['active'] as String?);
    } catch (_) {
      return const AccountsState([], null);
    }
  }

  Future<void> _save(AccountsState s) async {
    state = AsyncData(s);
    await safeSecureWrite(
      _storeKey,
      jsonEncode({
        'accounts': [for (final a in s.accounts) a.toJson()],
        'active': s.activeKey,
      }),
    );
  }

  AccountsState get _s => state.value ?? const AccountsState([], null);

  Future<void> upsert(SavedAccount a, {bool activate = true}) => _save(
    AccountsState([
      for (final x in _s.accounts)
        if (x.key != a.key) x,
      a,
    ], activate ? a.key : _s.activeKey),
  );

  Future<void> replace(SavedAccount a) => _save(
    AccountsState([
      for (final x in _s.accounts) x.key == a.key ? a : x,
    ], _s.activeKey),
  );

  Future<void> remove(String key) {
    final rest = [
      for (final x in _s.accounts)
        if (x.key != key) x,
    ];
    return _save(
      AccountsState(
        rest,
        _s.activeKey == key ? rest.firstOrNull?.key : _s.activeKey,
      ),
    );
  }

  Future<void> activate(String key) => _save(AccountsState(_s.accounts, key));
}

final accountsProvider = AsyncNotifierProvider<AccountsNotifier, AccountsState>(
  AccountsNotifier.new,
);

final activeAccountProvider = Provider<SavedAccount?>(
  (ref) => ref.watch(accountsProvider).value?.active,
);

// ── HTTP client ─────────────────────────────────────────────────────────

class AccountError implements Exception {
  const AccountError(this.code, [this.message, this.status]);
  final String code;
  final String? message;
  final int? status;
  @override
  String toString() => message ?? code;
}

class AccountClient {
  AccountClient(this.server, [this.token, hp.Client? http])
    : _http = http ?? hp.Client();
  final String server;
  final String? token;
  final hp.Client _http;

  Uri _u(String p) => Uri.parse('${normalizeServerUrl(server)}$p');
  Map<String, String> get _h => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };

  Future<Map<String, Object?>> _go(Future<hp.Response> Function() f) async {
    hp.Response r;
    try {
      r = await f().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AccountError(
        'timeout',
        "The server didn't answer. Check your connection.",
      );
    } catch (_) {
      throw const AccountError('offline', "Couldn't reach the server.");
    }
    Map<String, Object?> body = const {};
    try {
      final d = jsonDecode(r.body);
      if (d is Map) body = d.cast<String, Object?>();
    } catch (_) {}
    if (r.statusCode >= 400) {
      final e = body['error'];
      final code = e is Map ? '${e['code']}' : 'http_${r.statusCode}';
      final msg = e is Map ? e['message'] as String? : null;
      throw AccountError(code, msg ?? _friendly(code), r.statusCode);
    }
    return body;
  }

  static String _friendly(String code) => switch (code) {
    'username_taken' => 'That username is taken.',
    'email_taken' => 'That email is already used by another account.',
    'invalid_username' =>
      'Use 3–32 letters, numbers, dots, dashes or underscores.',
    'invalid_email' => "That email doesn't look right.",
    'unauthorized' => 'You were signed out. Please sign in again.',
    'rate_limited' => 'Too many tries. Wait a bit and try again.',
    'too_large' => 'This backup is too large for the server.',
    'not_found' => 'Not found on the server.',
    _ => 'Something went wrong ($code).',
  };

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) =>
      _go(() => _http.post(_u(path), headers: _h, body: jsonEncode(body)));
  Future<Map<String, Object?>> get(String path) =>
      _go(() => _http.get(_u(path), headers: _h));
  Future<Map<String, Object?>> delete(String path) =>
      _go(() => _http.delete(_u(path), headers: _h));

  Future<Map<String, Object?>> info() => get('/v1/info');

  Future<Map<String, Object?>> uploadBackup(
    Uint8List bytes, {
    required String label,
    required String device,
  }) => _go(
    () => _http.post(
      _u('/v1/backups'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/octet-stream',
        'x-backup-label': Uri.encodeComponent(label),
        'x-backup-device': Uri.encodeComponent(device),
      },
      body: bytes,
    ),
  );

  Future<Uint8List> downloadBackup(String id) async {
    final r = await _http
        .get(_u('/v1/backups/$id'), headers: {'authorization': 'Bearer $token'})
        .timeout(const Duration(minutes: 3));
    if (r.statusCode != 200)
      throw AccountError(
        'http_${r.statusCode}',
        "Couldn't download that backup.",
      );
    return r.bodyBytes;
  }
}

String deviceLabel() {
  if (kIsWeb) return 'Web browser';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iPhone / iPad',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.windows => 'Windows PC',
    TargetPlatform.linux => 'Linux',
    _ => 'Device',
  };
}

String platformName() => kIsWeb ? 'web' : defaultTargetPlatform.name;

// ── Actions ─────────────────────────────────────────────────────────────

class AccountActions {
  AccountActions(this.ref);
  final Ref ref;
  AccountsNotifier get _n => ref.read(accountsProvider.notifier);

  /// Creates an account. Returns the recovery key to show once.
  Future<String> signUp({
    required String server,
    required String username,
    String? email,
    required String password,
  }) async {
    final secret = await deriveLoginSecret(username, password);
    final recovery = newRecoveryKey();
    final wrapped = await wrapKey(recovery, password);
    final r = await AccountClient(server).post('/v1/accounts/signup', {
      'username': username.trim(),
      'email': email?.trim(),
      'secret': secret,
      'wrappedKey': wrapped,
      'device': deviceLabel(),
      'platform': platformName(),
    });
    final u = (r['user']! as Map).cast<String, Object?>();
    await _n.upsert(
      SavedAccount(
        server: normalizeServerUrl(server),
        username: u['username']! as String,
        userId: u['id']! as String,
        token: r['token']! as String,
        backupKey: normalizeRecoveryKey(recovery),
        email: u['email'] as String?,
      ),
    );
    return recovery;
  }

  /// Signs in. Throws AccountError('code_required') when a two-step code is
  /// needed. Returns false when backups couldn't be unlocked.
  Future<bool> signIn({
    required String server,
    required String login,
    required String password,
    String? code,
  }) async {
    // The secret is salted with the username, so sign-in uses the username
    // (the email is only for contact).
    final secret = await deriveLoginSecret(login, password);
    final r = await AccountClient(server).post('/v1/accounts/login', {
      'login': login.trim(),
      'secret': secret,
      'code': ?code,
      'device': deviceLabel(),
      'platform': platformName(),
    });
    final u = (r['user']! as Map).cast<String, Object?>();
    final wrapped = r['wrappedKey'] as String?;
    final key = wrapped == null ? null : await unwrapKey(wrapped, password);
    await _n.upsert(
      SavedAccount(
        server: normalizeServerUrl(server),
        username: u['username']! as String,
        userId: u['id']! as String,
        token: r['token']! as String,
        backupKey: key,
        email: u['email'] as String?,
        twoStep: u['twoStep'] == true,
      ),
    );
    return key != null || wrapped == null;
  }

  Future<void> signOut(SavedAccount a) async {
    try {
      await AccountClient(
        a.server,
        a.token,
      ).post('/v1/accounts/logout', const {});
    } catch (_) {}
    await _n.remove(a.key);
  }

  Future<void> useRecoveryKey(SavedAccount a, String key) =>
      _n.replace(a.copyWith(backupKey: normalizeRecoveryKey(key)));

  Future<void> changePassword(
    SavedAccount a,
    String current,
    String next,
  ) async {
    if (a.backupKey == null)
      throw const AccountError(
        'no_key',
        'Enter your recovery key first, so your backups stay readable.',
      );
    final c = AccountClient(a.server, a.token);
    await c.post('/v1/accounts/secret', {
      'current': await deriveLoginSecret(a.username, current),
      'secret': await deriveLoginSecret(a.username, next),
      'wrappedKey': await wrapKey(a.backupKey!, next),
    });
  }

  Future<void> deleteAccount(SavedAccount a, String password) async {
    await AccountClient(a.server, a.token).post('/v1/accounts/delete', {
      'secret': await deriveLoginSecret(a.username, password),
    });
    await _n.remove(a.key);
  }

  // Backups

  Future<void> backUpNow(
    SavedAccount a, {
    String label = 'Manual backup',
  }) async {
    final key = a.backupKey;
    if (key == null)
      throw const AccountError(
        'no_key',
        'Enter your recovery key to unlock backups on this device.',
      );
    final export = await ref.read(dataExportServiceProvider).buildExport();
    final json = jsonEncode(export.toJson());
    final bytes = kIsWeb
        ? _wrapSync((json, key))
        : await compute(_wrapSync, (json, key));
    await AccountClient(
      a.server,
      a.token,
    ).uploadBackup(bytes, label: label, device: deviceLabel());
    final latest =
        ref
            .read(accountsProvider)
            .value
            ?.accounts
            .where((x) => x.key == a.key)
            .firstOrNull ??
        a;
    await _n.replace(latest.copyWith(lastBackupAt: DateTime.now()));
  }

  Future<List<Map<String, Object?>>> listBackups(SavedAccount a) async {
    final r = await AccountClient(a.server, a.token).get('/v1/backups');
    return [
      for (final b in (r['backups'] as List? ?? const []))
        (b as Map).cast<String, Object?>(),
    ];
  }

  /// Downloads, decrypts and imports a backup into this device's data.
  Future<void> restore(SavedAccount a, String id) async {
    final key = a.backupKey;
    if (key == null)
      throw const AccountError(
        'no_key',
        'Enter your recovery key to unlock backups on this device.',
      );
    final bytes = await AccountClient(a.server, a.token).downloadBackup(id);
    final resolved = await DataImportService.resolveInBackground(
      bytes,
      password: key,
    );
    await ref
        .read(dataImportServiceProvider)
        .importData(resolved.json, mediaBlobs: resolved.mediaBlobs);
  }

  Future<void> deleteBackup(SavedAccount a, String id) =>
      AccountClient(a.server, a.token).delete('/v1/backups/$id');
}

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);

/// Automatic backups: at most once a day, when Prism is open.
final autoBackupListenerProvider = Provider<void>((ref) {
  Timer? timer;
  var running = false;
  Future<void> check() async {
    final a = ref.read(activeAccountProvider);
    if (running || a == null || !a.autoBackup || a.backupKey == null) return;
    final last = a.lastBackupAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 24))
      return;
    running = true;
    try {
      await ref
          .read(accountActionsProvider)
          .backUpNow(a, label: 'Automatic backup');
    } catch (e) {
      debugPrint('Automatic backup skipped: $e');
    } finally {
      running = false;
    }
  }

  timer = Timer(const Duration(seconds: 45), check);
  final periodic = Timer.periodic(const Duration(hours: 1), (_) => check());
  ref.onDispose(() {
    timer?.cancel();
    periodic.cancel();
  });
});
