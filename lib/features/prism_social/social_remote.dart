import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as hp;

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/social/models/social.dart'
    show SocialKind;
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_social_core/prism_social_core.dart' show SocRecord;

/// Record kind holding the server connection. It syncs to your own devices
/// (end-to-end encrypted by Prism sync) so they all use the same account.
const socialConnectionKind = 'socsrv.connection';

/// Prefix for images stored on the Social server.
const serverMediaPrefix = 'srv:';

class SocialConnection {
  const SocialConnection({
    required this.recordId,
    required this.url,
    required this.account,
    required this.token,
  });
  final String recordId;
  final String url;
  final String account;
  final String token;
  String get host => Uri.tryParse(url)?.host ?? url;

  // Value equality: unrelated database changes must not look like a new
  // connection (that would restart sync).
  @override
  bool operator ==(Object other) =>
      other is SocialConnection &&
      other.recordId == recordId &&
      other.url == url &&
      other.token == token &&
      other.account == account;
  @override
  int get hashCode => Object.hash(recordId, url, token, account);
}

final socialConnectionProvider = Provider<SocialConnection?>((ref) {
  final rows =
      ref.watch(trackerKindProvider(socialConnectionKind)).value ??
      const <TrackerRecord>[];
  final r = rows
      .where((r) => r.str('url') != null && r.str('token') != null)
      .firstOrNull;
  return r == null
      ? null
      : SocialConnection(
          recordId: r.id,
          url: r.str('url')!,
          account: r.str('account') ?? '',
          token: r.str('token')!,
        );
});

/// Overridable for tests (routes to an in-process server).
final socialHttpClientProvider = Provider<hp.Client>((ref) {
  final c = hp.Client();
  ref.onDispose(c.close);
  return c;
});

/// Network or server trouble (not a rule refusal).
class SocialServerError implements Exception {
  const SocialServerError(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => 'SocialServerError($status, $message)';
}

/// Normalises what people type: adds https:// and drops trailing slashes.
String normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Thin HTTP client for the Prism Social server.
class SocialServerClient {
  SocialServerClient(this.http, this.baseUrl, [this.token]);
  final hp.Client http;
  final String baseUrl;
  final String? token;

  Map<String, String> get _auth => {'authorization': 'Bearer $token'};
  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<hp.Response> _send(Future<hp.Response> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const SocialServerError('timeout');
    } on hp.ClientException catch (e) {
      throw SocialServerError(e.message);
    }
  }

  Never _fail(hp.Response r) {
    String? code;
    try {
      code = ((jsonDecode(r.body) as Map)['error'] as Map?)?['code'] as String?;
    } catch (_) {}
    if (code != null &&
        r.statusCode >= 400 &&
        r.statusCode < 500 &&
        !const {
          'unauthorized',
          'rate_limited',
          'bad_request',
          'unknown_method',
          'invite_required',
          'registration_closed',
          'too_many_profiles',
          'too_large',
          'quota_exceeded',
          'unsupported_media_type',
        }.contains(code)) {
      throw SocialDenied(code);
    }
    throw SocialServerError(
      code ?? 'HTTP ${r.statusCode}',
      status: r.statusCode,
    );
  }

  Future<Map<String, Object?>> info() async {
    final r = await _send(() => http.get(_u('/v1/info')));
    if (r.statusCode != 200) _fail(r);
    final m = jsonDecode(r.body);
    if (m is! Map || m['name'] != 'Prism Social')
      throw const SocialServerError('not_a_prism_server');
    return m.cast<String, Object?>();
  }

  Future<({String account, String token})> register({
    String? inviteCode,
  }) async {
    final r = await _send(
      () => http.post(
        _u('/v1/auth/register'),
        headers: {
          if (inviteCode != null && inviteCode.isNotEmpty)
            'x-registration-code': inviteCode,
        },
      ),
    );
    if (r.statusCode != 201) _fail(r);
    final m = jsonDecode(r.body) as Map;
    return (account: m['account']! as String, token: m['token']! as String);
  }

  Future<Object?> rpc(String method, Map<String, Object?> args) async {
    final r = await _send(
      () => http.post(
        _u('/v1/rpc/$method'),
        headers: {..._auth, 'content-type': 'application/json'},
        body: jsonEncode(args),
      ),
    );
    if (r.statusCode != 200) _fail(r);
    return (jsonDecode(r.body) as Map)['result'];
  }

  /// Null when nothing changed since [version].
  Future<({int version, Set<String> mine, List<SocRecord> records})?> sync(
    int? version,
  ) async {
    final r = await _send(
      () => http.get(
        _u('/v1/sync', version == null ? null : {'v': '$version'}),
        headers: _auth,
      ),
    );
    if (r.statusCode == 304) return null;
    if (r.statusCode != 200) _fail(r);
    final m = jsonDecode(r.body) as Map;
    return (
      version: (m['version']! as num).toInt(),
      mine: {for (final x in (m['profiles'] as List?) ?? const []) '$x'},
      records: [
        for (final x in m['records']! as List)
          SocRecord.fromJson((x as Map).cast<String, Object?>()),
      ],
    );
  }

  Future<String> uploadMedia(Uint8List bytes, String mime) async {
    final r = await _send(
      () => http.post(
        _u('/v1/media'),
        headers: {..._auth, 'content-type': mime},
        body: bytes,
      ),
    );
    if (r.statusCode != 201) _fail(r);
    return '$serverMediaPrefix${(jsonDecode(r.body) as Map)['id']}';
  }

  Future<Uint8List?> media(String id) async {
    final r = await _send(
      () => http.get(
        _u('/v1/media/${id.substring(serverMediaPrefix.length)}'),
        headers: _auth,
      ),
    );
    return r.statusCode == 200 ? r.bodyBytes : null;
  }

  Future<void> deleteAccount() async {
    final r = await _send(() => http.delete(_u('/v1/account'), headers: _auth));
    if (r.statusCode != 200) _fail(r);
  }
}

SocialServerClient? _client(Ref ref) {
  final c = ref.watch(socialConnectionProvider);
  return c == null
      ? null
      : SocialServerClient(ref.watch(socialHttpClientProvider), c.url, c.token);
}

final socialServerClientProvider = Provider<SocialServerClient?>(_client);

/// Images from the server, cached for the session.
final remoteSocialImageProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  id,
) async {
  final c = ref.watch(socialServerClientProvider);
  if (c == null) return null;
  try {
    return await c.media(id);
  } catch (_) {
    return null;
  }
});

// ───────────────────────── Sync ─────────────────────────

@immutable
class SocialSyncStatus {
  const SocialSyncStatus({this.lastSync, this.error, this.syncing = false});
  final DateTime? lastSync;
  final String? error;
  final bool syncing;
}

/// Mirrors the server's snapshot into local Social rows, so every screen
/// works exactly as on-device. Polls while connected.
class SocialSyncNotifier extends Notifier<SocialSyncStatus> {
  int? _version;
  Timer? _timer;
  Future<void>? _running;
  bool _again = false;

  static const interval = Duration(seconds: 15);

  @override
  SocialSyncStatus build() {
    final conn = ref.watch(socialConnectionProvider);
    _version = null;
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (conn != null) {
      _timer = Timer.periodic(interval, (_) => syncNow());
      Future.microtask(syncNow);
    }
    return const SocialSyncStatus();
  }

  /// Syncs now (coalesces overlapping calls).
  Future<void> syncNow() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _run().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        unawaited(syncNow());
      }
    });
  }

  Future<void> _run() async {
    final client = ref.read(socialServerClientProvider);
    if (client == null) return;
    state = SocialSyncStatus(lastSync: state.lastSync, syncing: true);
    final repo = ref.read(trackerRecordRepositoryProvider);
    try {
      final snap = await client.sync(_version);
      if (!ref.mounted) return;
      if (snap != null) {
        await applySnapshot(repo, snap.records, mine: snap.mine);
        _version = snap.version;
      }
      if (ref.mounted) state = SocialSyncStatus(lastSync: DateTime.now());
    } catch (e) {
      if (ref.mounted)
        state = SocialSyncStatus(
          lastSync: state.lastSync,
          error: e is SocialServerError ? e.message : '$e',
        );
    }
  }

  /// Forces a full download next time (after writes).
  void invalidate() => _version = null;
}

final socialSyncProvider =
    NotifierProvider<SocialSyncNotifier, SocialSyncStatus>(
      SocialSyncNotifier.new,
    );

String _sig(TrackerRecord r) => jsonEncode([
  r.parentId,
  r.title,
  r.body,
  r.memberId,
  r.occurredAt?.toUtc().toIso8601String(),
  r.createdAt.toUtc().toIso8601String(),
  r.fields,
]);

/// Makes local `soc.*` rows match [records]. Rows that disappear are kept
/// but marked `_gone`, because the database can't re-create a deleted id
/// and the server may show them again (e.g. after an unblock).
Future<void> applySnapshot(
  EntityRepository<TrackerRecord> repo,
  List<SocRecord> records, {
  Set<String> mine = const {},
}) async {
  final local = {
    for (final r in await repo.getAll())
      if (r.kind.startsWith('soc.')) r.id: r,
  };
  final seen = <String>{};
  for (final s in records) {
    if (!s.kind.startsWith('soc.')) continue;
    seen.add(s.id);
    // Profiles this account manages are marked so the app only acts as them.
    final next = TrackerSocialStore.toTracker(
      s.kind == SocKind.profile && mine.contains(s.id)
          ? s.withFields({'_mine': true})
          : s,
    );
    final cur = local[s.id];
    if (cur == null) {
      try {
        await repo.create(next);
      } catch (e) {
        debugPrint('Social mirror: could not add ${s.id}: $e');
      }
    } else if (cur.flag('_gone') || _sig(cur) != _sig(next)) {
      await repo.update(next.copyWith(modifiedAt: s.modifiedAt));
    }
  }
  for (final r in local.values) {
    if (!seen.contains(r.id) && !r.flag('_gone'))
      await repo.update(r.withFields({'_gone': true}));
  }
}

// ───────────────────────── Remote backend ─────────────────────────

/// Server mode: every action goes to the Prism Social server, which runs
/// the same rules for everyone; results arrive through [SocialSyncNotifier].
class RemoteSocialBackend implements SocialBackend {
  RemoteSocialBackend(this.ref, this.conn);
  final Ref ref;
  final SocialConnection conn;

  @override
  String get name => conn.host;
  @override
  bool get reachesOtherDevices => true;

  SocialServerClient get _c => SocialServerClient(
    ref.read(socialHttpClientProvider),
    conn.url,
    conn.token,
  );

  Future<Object?> _call(String method, Map<String, Object?> args) async {
    final result = await _c.rpc(method, args);
    final sync = ref.read(socialSyncProvider.notifier)..invalidate();
    await sync.syncNow();
    return result;
  }

  /// Local images are uploaded first so other people can see them.
  Future<String?> _media(String? id) async {
    if (id == null || id.startsWith(serverMediaPrefix)) return id;
    final r = await ref.read(trackerRecordRepositoryProvider).getById(id);
    final data = r?.kind == SocialKind.media ? r!.str('data') : null;
    if (data == null) return null;
    return _c.uploadMedia(base64Decode(data), r!.str('mime') ?? 'image/jpeg');
  }

  Future<List<String>> _mediaList(List<String> ids) async => [
    for (final id in ids) ?await _media(id),
  ];

  Future<Map<String, Object?>> _withMedia(Map<String, Object?> m) async => {
    ...m,
    if (m['avatar'] is String) 'avatar': await _media(m['avatar']! as String),
    if (m['banner'] is String) 'banner': await _media(m['banner']! as String),
  };

  Map<String, Object?> _a(SocialActor a) => a.toJson();

  @override
  Future<String> createProfile({
    required String username,
    required String systemName,
    String? description,
    bool primary = false,
  }) async =>
      await _call('createProfile', {
            'username': username,
            'systemName': systemName,
            'description': description,
            'primary': primary,
          })
          as String;
  @override
  Future<void> updateProfile(
    String profileId,
    Map<String, Object?> changes, {
    String? systemName,
    String? description,
  }) async => _call('updateProfile', {
    'profileId': profileId,
    'changes': await _withMedia(changes),
    'systemName': systemName,
    'description': description,
  });
  static final _touched = <String, DateTime>{};
  @override
  Future<void> touch(String profileId) async {
    final last = _touched[profileId];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2))
      return;
    _touched[profileId] = DateTime.now();
    await _c.rpc('touch', {'profileId': profileId});
  }

  @override
  Future<String> saveAlter(
    String profileId, {
    String? editingId,
    String? memberId,
    required String name,
    Map<String, Object?> fields = const {},
    String? description,
  }) async =>
      await _call('saveAlter', {
            'profileId': profileId,
            'editingId': editingId,
            'memberId': memberId,
            'name': name,
            'fields': await _withMedia(fields),
            'description': description,
          })
          as String;
  @override
  Future<void> deleteAlter(String profileId, String alterId) =>
      _call('deleteAlter', {'profileId': profileId, 'alterId': alterId});
  @override
  Future<void> sendRequest(SocialActor from, String to, {String? note}) =>
      _call('sendRequest', {'from': _a(from), 'to': to, 'note': note});
  @override
  Future<void> acceptRequest(SocialActor actor, String requestId) =>
      _call('acceptRequest', {'actor': _a(actor), 'requestId': requestId});
  @override
  Future<void> declineRequest(SocialActor actor, String requestId) =>
      _call('declineRequest', {'actor': _a(actor), 'requestId': requestId});
  @override
  Future<void> cancelRequest(SocialActor actor, String requestId) =>
      _call('cancelRequest', {'actor': _a(actor), 'requestId': requestId});
  @override
  Future<void> removeFriend(SocialActor actor, String other) =>
      _call('removeFriend', {'actor': _a(actor), 'other': other});
  @override
  Future<void> toggleFavorite(SocialActor actor, String other) =>
      _call('toggleFavorite', {'actor': _a(actor), 'other': other});
  @override
  Future<void> toggleFollow(SocialActor actor, String other) =>
      _call('toggleFollow', {'actor': _a(actor), 'other': other});
  @override
  Future<void> block(SocialActor actor, String other) =>
      _call('block', {'actor': _a(actor), 'other': other});
  @override
  Future<void> unblock(SocialActor actor, String other) =>
      _call('unblock', {'actor': _a(actor), 'other': other});
  @override
  Future<void> report(
    SocialActor actor, {
    required String targetType,
    required String targetId,
    required String reason,
  }) => _call('report', {
    'actor': _a(actor),
    'targetType': targetType,
    'targetId': targetId,
    'reason': reason,
  });
  @override
  Future<String> openConversation(SocialActor me, SocialActor them) async =>
      await _call('openConversation', {'me': _a(me), 'them': _a(them)})
          as String;
  @override
  Future<String> sendMessage(
    SocialActor actor,
    String conversationId, {
    String body = '',
    List<String> media = const [],
    String? replyTo,
  }) async =>
      await _call('sendMessage', {
            'actor': _a(actor),
            'conversationId': conversationId,
            'body': body,
            'media': await _mediaList(media),
            'replyTo': replyTo,
          })
          as String;
  @override
  Future<void> editMessage(SocialActor actor, String messageId, String body) =>
      _call('editMessage', {
        'actor': _a(actor),
        'messageId': messageId,
        'body': body,
      });
  @override
  Future<void> deleteMessage(SocialActor actor, String messageId) =>
      _call('deleteMessage', {'actor': _a(actor), 'messageId': messageId});
  @override
  Future<void> react(SocialActor actor, String messageId, String emoji) =>
      _call('react', {
        'actor': _a(actor),
        'messageId': messageId,
        'emoji': emoji,
      });
  @override
  Future<void> markRead(SocialActor actor, String conversationId) =>
      _call('markRead', {'actor': _a(actor), 'conversationId': conversationId});
  @override
  Future<void> markUnread(SocialActor actor, String conversationId) => _call(
    'markUnread',
    {'actor': _a(actor), 'conversationId': conversationId},
  );
  @override
  Future<void> toggleMute(SocialActor actor, String conversationId) => _call(
    'toggleMute',
    {'actor': _a(actor), 'conversationId': conversationId},
  );
  @override
  Future<void> togglePin(
    SocialActor actor,
    String conversationId,
    String messageId,
  ) => _call('togglePin', {
    'actor': _a(actor),
    'conversationId': conversationId,
    'messageId': messageId,
  });
  @override
  Future<String> createPost(
    SocialActor actor, {
    required String type,
    String title = '',
    String body = '',
    List<String> media = const [],
    String? link,
    String? quoteSource,
    Map<String, Object?>? milestone,
    Audience? audience,
    String? circleId,
  }) async =>
      await _call('createPost', {
            'actor': _a(actor),
            'type': type,
            'title': title,
            'body': body,
            'media': await _mediaList(media),
            'link': link,
            'quoteSource': quoteSource,
            'milestone': milestone,
            'audience': audience?.name,
            'circleId': circleId,
          })
          as String;
  @override
  Future<void> editPost(
    SocialActor actor,
    String postId, {
    String? title,
    String? body,
    Audience? audience,
  }) => _call('editPost', {
    'actor': _a(actor),
    'postId': postId,
    'title': title,
    'body': body,
    'audience': audience?.name,
  });
  @override
  Future<void> deletePost(SocialActor actor, String postId) =>
      _call('deletePost', {'actor': _a(actor), 'postId': postId});
  @override
  Future<void> toggleReact(SocialActor actor, String postId, String type) =>
      _call('toggleReact', {
        'actor': _a(actor),
        'postId': postId,
        'type': type,
      });
  @override
  Future<String> comment(
    SocialActor actor,
    String postId,
    String body, {
    String? replyTo,
  }) async =>
      await _call('comment', {
            'actor': _a(actor),
            'postId': postId,
            'body': body,
            'replyTo': replyTo,
          })
          as String;
  @override
  Future<void> deleteComment(SocialActor actor, String commentId) =>
      _call('deleteComment', {'actor': _a(actor), 'commentId': commentId});
  @override
  Future<String> reblog(
    SocialActor actor,
    String postId, {
    String note = '',
    Audience? audience,
  }) async =>
      await _call('reblog', {
            'actor': _a(actor),
            'postId': postId,
            'note': note,
            'audience': audience?.name,
          })
          as String;
  @override
  Future<void> togglePinPost(SocialActor actor, String postId) =>
      _call('togglePinPost', {'actor': _a(actor), 'postId': postId});
  @override
  Future<String> saveCircle(
    SocialActor actor, {
    String? editingId,
    required String name,
    required List<String> members,
  }) async =>
      await _call('saveCircle', {
            'actor': _a(actor),
            'editingId': editingId,
            'name': name,
            'members': members,
          })
          as String;
  @override
  Future<void> deleteCircle(SocialActor actor, String circleId) =>
      _call('deleteCircle', {'actor': _a(actor), 'circleId': circleId});
  @override
  Future<void> markNotifications(
    String profileId, {
    String? id,
    bool read = true,
  }) => _call('markNotifications', {
    'profileId': profileId,
    'id': id,
    'read': read,
  });
  @override
  Future<void> deleteNotification(String profileId, String id) =>
      _call('deleteNotification', {'profileId': profileId, 'id': id});
}

// ───────────────────────── Connecting ─────────────────────────

/// Connects this Prism account to a server. Optionally recreates your
/// existing on-device system profiles (and alter profiles) there first.
Future<void> connectToSocialServer(
  SocialReader read, {
  required String url,
  String? inviteCode,
  bool bringProfiles = true,
}) async {
  final base = normalizeServerUrl(url);
  final http = read(socialHttpClientProvider);
  await SocialServerClient(http, base).info();
  final reg = await SocialServerClient(
    http,
    base,
  ).register(inviteCode: inviteCode);
  final client = SocialServerClient(http, base, reg.token);
  if (bringProfiles) {
    final local = read(socialProfilesProvider);
    final alters = read(socialAltersProvider);
    for (final p in local) {
      final id =
          await client.rpc('createProfile', {
                'username': p.username,
                'systemName': p.systemName,
                'description': p.description.isEmpty ? null : p.description,
                'primary': p.r.flag('primary'),
              })
              as String;
      final keep = {
        for (final e in p.r.fields.entries)
          if (!const {
            'username',
            'primary',
            'owner',
            'avatar',
            'banner',
            'pinned',
            'lastActive',
          }.contains(e.key))
            e.key: e.value,
      };
      await client.rpc('updateProfile', {'profileId': id, 'changes': keep});
      for (final a in alters.where((a) => a.profileId == p.id)) {
        await client.rpc('saveAlter', {
          'profileId': id,
          'memberId': a.memberId,
          'name': a.name.isEmpty ? '—' : a.name,
          'description': a.description,
          'fields': {
            for (final e in a.r.fields.entries)
              if (!const {'avatar', 'banner'}.contains(e.key)) e.key: e.value,
          },
        });
      }
    }
  }
  final t = read(trackerNotifierProvider.notifier);
  for (final old
      in read(trackerKindProvider(socialConnectionKind)).value ??
          const <TrackerRecord>[]) {
    await t.delete(old.id, children: false);
  }
  await t.create(
    kind: socialConnectionKind,
    title: base,
    fields: {'url': base, 'account': reg.account, 'token': reg.token},
  );
  await read(actingStoredProvider.notifier).set(null);
}

/// Stops using the server on all your devices (the server account stays
/// unless [deleteAccount]). Mirrored rows are hidden.
Future<void> disconnectSocialServer(
  SocialReader read, {
  bool deleteAccount = false,
}) async {
  final conn = read(socialConnectionProvider);
  if (conn == null) return;
  if (deleteAccount)
    await SocialServerClient(
      read(socialHttpClientProvider),
      conn.url,
      conn.token,
    ).deleteAccount();
  await read(
    trackerNotifierProvider.notifier,
  ).delete(conn.recordId, children: false);
  await applySnapshot(read(trackerRecordRepositoryProvider), const []);
  await read(actingStoredProvider.notifier).set(null);
}
